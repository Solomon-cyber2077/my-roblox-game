/*
	Renders a `lune run preview` export in headless Chromium.

	  node tools/preview/render.mjs <scene.json> <out.png> [options]
	  node tools/preview/render.mjs <scene.json> <out.mp4> --video=12 [options]

	Options:
	  --cam=<name>|x,y,z:lx,ly,lz  a preset below, or a position and a point to look at
	  --size=1280x720              output size
	  --t=<seconds>                ride time for a still (the landscape scrolls with it)
	  --video=<seconds>            render a ride: one frame per 1/fps, encoded with ffmpeg
	  --fps=30
	  --pan=<degrees>              turn the camera this far over the length of a video
	  --sky=<sky.json>             draw with this sky state instead of the export's

	Install once: (cd tools/preview && npm install). Chromium comes from Playwright;
	a GPU is not needed (SwiftShader), it is just slower.
*/

import { createServer } from 'node:http';
import { readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { extname, join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { chromium } from 'playwright';

const HERE = dirname(fileURLToPath(import.meta.url));

export const CAMERAS = {
	// beside the locomotive, looking ahead and up over the platform side
	ahead: { pos: [60, 13, -16], look: [700, 120, 260] },
	// from the far side of the train, over the roofs, into the station side's sky
	station: { pos: [-30, 18, -22], look: [80, 110, 520] },
	// the far side: over the fields away from the platform
	far: { pos: [10, 16, 18], look: [-200, 90, -600] },
	// high and wide, the whole train against the sky
	wide: { pos: [-140, 60, -120], look: [260, 110, 260] },
	// down the line behind the train
	behind: { pos: [-260, 14, -14], look: [-1200, 80, -160] },
};

function parseArgs(argv) {
	const positional = [];
	const options = {};
	for (const arg of argv) {
		const match = /^--([^=]+)(?:=(.*))?$/.exec(arg);
		if (match) options[match[1]] = match[2] ?? 'true';
		else positional.push(arg);
	}
	return { positional, options };
}

function camera(spec) {
	if (CAMERAS[spec]) return CAMERAS[spec];
	const [pos, look] = spec.split(':').map((s) => s.split(',').map(Number));
	return { pos, look };
}

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json' };

function serve(files) {
	const server = createServer(async (req, res) => {
		const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
		const mapped = files[path];
		const file = mapped || join(HERE, path);
		if (!file.startsWith(HERE) && !mapped) {
			res.writeHead(403).end();
			return;
		}
		try {
			const body = await readFile(file);
			res.writeHead(200, { 'content-type': TYPES[extname(file)] || 'application/octet-stream' });
			res.end(body);
		} catch {
			res.writeHead(404).end();
		}
	});
	return new Promise((done) => server.listen(0, '127.0.0.1', () => done(server)));
}

export async function render({ scene, out, cam = 'ahead', size = '1280x720', t = 0, video, fps = 30, pan = 0, sky }) {
	const [width, height] = size.split('x').map(Number);
	const files = { '/scene.json': resolve(scene) };
	const server = await serve(files);
	const port = server.address().port;
	const browser = await chromium.launch({
		args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
	});
	try {
		const page = await browser.newPage({ viewport: { width, height } });
		page.on('console', (msg) => {
			if (msg.type() === 'error' || msg.type() === 'warning') console.log(`[page] ${msg.text()}`);
		});
		page.on('pageerror', (err) => console.log(`[page error] ${err.message}`));
		await page.goto(`http://127.0.0.1:${port}/viewer.html`);
		await page.waitForFunction(() => window.viewerReady === true);
		const info = await page.evaluate(([w, h]) => window.startViewer('/scene.json', w, h), [width, height]);
		console.log(`loaded ${info.parts} parts, ${info.lights} lights, ${info.frames} sky frames`);
		if (sky) {
			const state = JSON.parse(await readFile(sky, 'utf8'));
			await page.evaluate((s) => window.viewer.applySky(s), state);
		}
		const base = camera(cam);
		const grab = async (time, turn) => {
			return page.evaluate(
				([c, time, turn]) => {
					const v = window.viewer;
					// turn the look point about the camera by `turn` degrees
					const dx = c.look[0] - c.pos[0];
					const dz = c.look[2] - c.pos[2];
					const a = (turn * Math.PI) / 180;
					const look = [c.pos[0] + dx * Math.cos(a) - dz * Math.sin(a), c.look[1], c.pos[2] + dx * Math.sin(a) + dz * Math.cos(a)];
					v.setTime(time);
					v.setCamera({ pos: c.pos, look, fov: c.fov });
					v.render();
					return v.renderer.domElement.toDataURL('image/png');
				},
				[base, time, turn],
			);
		};
		const decode = (url) => Buffer.from(url.slice(url.indexOf(',') + 1), 'base64');
		if (video) {
			const seconds = Number(video);
			const frames = Math.round(seconds * fps);
			const dir = `${out}.frames`;
			await rm(dir, { recursive: true, force: true });
			await mkdir(dir, { recursive: true });
			const started = Date.now();
			for (let i = 0; i < frames; i++) {
				const time = Number(t) + i / fps;
				const png = decode(await grab(time, (Number(pan) * i) / Math.max(1, frames - 1)));
				await writeFile(join(dir, `f${String(i).padStart(5, '0')}.png`), png);
				if (i % 30 === 0) {
					const each = (Date.now() - started) / (i + 1) / 1000;
					console.log(`frame ${i + 1}/${frames} (${each.toFixed(2)} s each)`);
				}
			}
			const result = spawnSync(
				'ffmpeg',
				['-y', '-loglevel', 'error', '-framerate', String(fps), '-i', join(dir, 'f%05d.png'),
					'-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-preset', 'slow', '-movflags', '+faststart', out],
				{ stdio: 'inherit' },
			);
			if (result.status !== 0) throw new Error('ffmpeg failed');
			await rm(dir, { recursive: true, force: true });
			console.log(`wrote ${out} (${frames} frames)`);
		} else {
			await writeFile(out, decode(await grab(Number(t), 0)));
			console.log(`wrote ${out}`);
		}
	} finally {
		await browser.close();
		server.close();
	}
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
	const { positional, options } = parseArgs(process.argv.slice(2));
	if (positional.length < 2 || !existsSync(positional[0])) {
		console.log('usage: node tools/preview/render.mjs <scene.json> <out.png|out.mp4> [--cam=ahead] [--video=12]');
		process.exit(1);
	}
	await render({ scene: positional[0], out: positional[1], ...options });
}
