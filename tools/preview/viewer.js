/*
	Draws a `lune run preview` export with three.js: every part (blocks, wedges,
	cylinders, balls) instanced by shape and material, the lights, the sky dome, the
	game's own sky objects (BillboardGuis) as sprites, and the post stack (bloom,
	exposure, a filmic curve, then each ColorCorrectionEffect in order).

	It approximates Roblox's Future lighting; it is a way to judge composition, colour
	and mood without Studio, not a pixel match. The constants in CAL are the knobs
	that map Roblox units (Brightness, Range, Density) onto this renderer.

	Ride exports scroll: parts tagged k=1 (the landscape) slide past the train at the
	export's speed, and a timeline of sky states (frames) plays in step with them.
*/

import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { createSky, linear } from './sky.js';
import { rasterize } from './gui.js';

export const CAL = {
	sun: 3.2, // directional light per unit of Lighting.Brightness
	shift: 2.0, // Lighting.ColorShift_Top, on top of it
	ambient: 1.6, // Lighting.Ambient
	outdoor: 2.2, // Lighting.OutdoorAmbient (sky-facing fill)
	point: 0.16, // light intensity per Brightness x Range (1/d falloff, closing at the Range)
	neon: 2.4, // Neon parts glow above the bloom threshold
	exposure: 1.35, // before Lighting.ExposureCompensation
	fog: 0.0024, // fog per stud per unit of Atmosphere.Density
	sky: 1.0, // sky dome brightness
	nightSky: 1.15,
	pointLights: 14, // nearest lights that really light the scene
	heavenDistance: 20000, // sky objects drawn this far out (beyond every part)
};

// Roblox's Atmosphere thickens with distance but never quite hides the skyline:
// THREE.Fog's near and far carry the density per stud and the cap.
THREE.ShaderChunk.fog_fragment = /* glsl */ `
#ifdef USE_FOG
	float fogFactor = min( 1.0 - exp( - fogNear * vFogDepth ), fogFar );
	gl_FragColor.rgb = mix( gl_FragColor.rgb, fogColor, fogFactor );
#endif`;

const MATERIALS = {
	Plastic: [0.75, 0],
	SmoothPlastic: [0.55, 0],
	Wood: [0.85, 0],
	WoodPlanks: [0.85, 0],
	Slate: [0.9, 0],
	Concrete: [0.95, 0],
	Brick: [0.95, 0],
	Cobblestone: [0.95, 0],
	Granite: [0.9, 0],
	Marble: [0.45, 0],
	Metal: [0.45, 0.65],
	DiamondPlate: [0.4, 0.65],
	CorrodedMetal: [0.8, 0.45],
	Foil: [0.3, 0.8],
	Grass: [1, 0],
	LeafyGrass: [1, 0],
	Ground: [1, 0],
	Mud: [0.85, 0],
	Sand: [1, 0],
	Snow: [0.85, 0],
	Glacier: [0.35, 0],
	Ice: [0.3, 0],
	Rock: [0.95, 0],
	Basalt: [0.95, 0],
	Pebble: [0.95, 0],
	Pavement: [0.95, 0],
	Asphalt: [0.95, 0],
	Limestone: [0.9, 0],
	Sandstone: [0.95, 0],
	Salt: [0.9, 0],
	Fabric: [1, 0],
	Cardboard: [1, 0],
	Carpet: [1, 0],
	Leather: [0.75, 0],
	Plaster: [0.95, 0],
	Rubber: [0.9, 0],
	CeramicTiles: [0.5, 0],
	ClayRoofTiles: [0.9, 0],
	RoofShingles: [0.9, 0],
	Glass: [0.08, 0],
	ForceField: [0.5, 0],
};

function wedgeGeometry() {
	// full height at +Z, sloping down to the front edge at -Z (as Roblox's WedgePart)
	const h = 0.5;
	const v = [
		[-h, -h, h], [h, -h, h], [h, h, h], [-h, h, h], // back
		[-h, -h, -h], [h, -h, -h], [h, -h, h], [-h, -h, h], // bottom
		[-h, h, h], [h, h, h], [h, -h, -h], [-h, -h, -h], // slope
	];
	const positions = [];
	const quad = (a, b, c, d) => positions.push(...a, ...b, ...c, ...a, ...c, ...d);
	quad(v[1], v[0], v[3], v[2]);
	quad(v[4], v[5], v[6], v[7]);
	quad(v[8], v[9], v[10], v[11]);
	positions.push(-h, -h, -h, -h, -h, h, -h, h, h); // left side
	positions.push(h, -h, h, h, -h, -h, h, h, h); // right side
	const g = new THREE.BufferGeometry();
	g.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
	g.computeVertexNormals();
	return g;
}

const GEOMETRY = {
	B: () => new THREE.BoxGeometry(1, 1, 1),
	W: wedgeGeometry,
	C: () => new THREE.CylinderGeometry(0.5, 0.5, 1, 22).rotateZ(Math.PI / 2),
	S: () => new THREE.SphereGeometry(0.5, 22, 16),
};

function srgb(rgb, scale = 1) {
	const c = new THREE.Color();
	c.setRGB(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, THREE.SRGBColorSpace);
	return c.multiplyScalar(scale);
}

// Roblox's sun for a ClockTime and GeographicLatitude (east along +X, the way the train runs).
export function sunDirection(clock, latitude) {
	const hourAngle = ((clock - 12.3) / 24) * Math.PI * 2;
	const phi = (latitude * Math.PI) / 180;
	const east = -Math.sin(hourAngle);
	const north = -Math.cos(hourAngle) * Math.sin(phi);
	const up = Math.cos(hourAngle) * Math.cos(phi);
	return new THREE.Vector3(east, up, -north).normalize();
}

const FinalShader = {
	uniforms: {
		tDiffuse: { value: null },
		uExposure: { value: 1 },
		uGrades: { value: [] },
		uGradeCount: { value: 0 },
	},
	vertexShader: /* glsl */ `
		varying vec2 vUv;
		void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
	fragmentShader: /* glsl */ `
		uniform sampler2D tDiffuse;
		uniform float uExposure;
		uniform vec4 uGrades[8]; // brightness, contrast, saturation, unused
		uniform vec3 uTints[8];
		uniform int uGradeCount;
		varying vec2 vUv;
		vec3 aces(vec3 x) {
			return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
		}
		vec3 toSrgb(vec3 c) {
			return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
		}
		void main() {
			vec3 c = texture2D(tDiffuse, vUv).rgb * uExposure;
			c = toSrgb(aces(c));
			for (int i = 0; i < 8; i++) {
				if (i >= uGradeCount) break;
				vec4 g = uGrades[i];
				c += g.x;
				c = (c - 0.5) * (1.0 + g.y) + 0.5;
				float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
				c = mix(vec3(l), c, 1.0 + g.z);
				c *= uTints[i];
			}
			gl_FragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
		}`,
};

export class Viewer {
	constructor(canvas, width, height) {
		this.width = width;
		this.height = height;
		this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
		this.renderer.setSize(width, height, false);
		this.renderer.setPixelRatio(1);
		this.renderer.toneMapping = THREE.NoToneMapping;
		this.renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
		this.scene = new THREE.Scene();
		// a near plane of 2 keeps depth precise enough to set the sky (20k) behind ranges at 10k
		this.camera = new THREE.PerspectiveCamera(70, width / height, 2, 60000);
		this.world = new THREE.Group(); // the landscape: scrolls past the train
		this.train = new THREE.Group(); // stays put, as the train does in the game
		this.heavens = new THREE.Group();
		this.scene.add(this.world, this.train, this.heavens);
		this.sky = createSky();
		this.scene.add(this.sky.mesh);
		this.ambient = new THREE.AmbientLight(0xffffff, 0);
		this.hemi = new THREE.HemisphereLight(0xffffff, 0x000000, 0);
		this.sun = new THREE.DirectionalLight(0xffffff, 0);
		this.sun.target.position.set(0, 0, 0);
		// Lighting.ColorShift_Top: extra light of its own colour on faces toward the sun or moon
		this.shift = new THREE.DirectionalLight(0xffffff, 0);
		this.shift.target.position.set(0, 0, 0);
		this.scene.add(this.ambient, this.hemi, this.sun, this.sun.target, this.shift, this.shift.target);
		this.pointLights = [];
		this.lights = [];
		this.sprites = [];
		this.time = 0;
		this.speed = 0;

		const target = new THREE.WebGLRenderTarget(width, height, { type: THREE.HalfFloatType });
		this.composer = new EffectComposer(this.renderer, target);
		this.composer.addPass(new RenderPass(this.scene, this.camera));
		this.bloom = new UnrealBloomPass(new THREE.Vector2(width, height), 0.6, 0.5, 1.0);
		this.composer.addPass(this.bloom);
		this.final = new ShaderPass({
			...FinalShader,
			uniforms: {
				tDiffuse: { value: null },
				uExposure: { value: 1 },
				uGrades: { value: Array.from({ length: 8 }, () => new THREE.Vector4()) },
				uTints: { value: Array.from({ length: 8 }, () => new THREE.Vector3(1, 1, 1)) },
				uGradeCount: { value: 0 },
			},
		});
		this.composer.addPass(this.final);
	}

	loadParts(parts) {
		const groups = new Map();
		for (const part of parts) {
			const neon = part.m === 'Neon';
			const transparent = !neon && (part.t || 0) > 0.02;
			const bucket = transparent ? Math.round(part.t * 10) / 10 : 0;
			const layer = part.k === 1 ? 'w' : 't';
			const key = `${part.s}|${neon ? 'Neon' : part.m}|${bucket}|${layer}`;
			let group = groups.get(key);
			if (!group) {
				group = { shape: part.s, material: part.m, neon, transparent, bucket, layer, list: [] };
				groups.set(key, group);
			}
			group.list.push(part);
		}
		const m = new THREE.Matrix4();
		const basis = new THREE.Matrix4();
		const geometries = {};
		for (const group of groups.values()) {
			const geometry = (geometries[group.shape] ||= GEOMETRY[group.shape]());
			let material;
			if (group.neon) {
				material = new THREE.MeshBasicMaterial({ color: 0xffffff });
			} else {
				const [roughness, metalness] = MATERIALS[group.material] || [0.8, 0];
				material = new THREE.MeshStandardMaterial({
					color: 0xffffff,
					roughness,
					metalness,
					transparent: group.transparent,
					opacity: 1 - group.bucket,
					depthWrite: !group.transparent,
				});
			}
			const mesh = new THREE.InstancedMesh(geometry, material, group.list.length);
			group.list.forEach((part, i) => {
				const [sx, sy, sz] = part.z;
				const r = part.r;
				basis.set(r[0], r[3], r[6], 0, r[1], r[4], r[7], 0, r[2], r[5], r[8], 0, 0, 0, 0, 1);
				let scale;
				if (part.s === 'C') {
					const d = Math.min(sy, sz);
					scale = new THREE.Vector3(sx, d, d);
				} else if (part.s === 'S') {
					const d = Math.min(sx, sy, sz);
					scale = new THREE.Vector3(d, d, d);
				} else {
					scale = new THREE.Vector3(sx, sy, sz);
				}
				m.copy(basis).scale(scale).setPosition(part.p[0], part.p[1], part.p[2]);
				mesh.setMatrixAt(i, m);
				const color = srgb(part.c, group.neon ? CAL.neon : 1);
				if (!group.neon && part.f > 0.1) color.multiplyScalar(1.15);
				mesh.setColorAt(i, color);
			});
			mesh.instanceMatrix.needsUpdate = true;
			if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
			mesh.frustumCulled = false;
			(group.layer === 'w' ? this.world : this.train).add(mesh);
		}
	}

	loadLights(lights) {
		this.lights = lights.map((l) => ({
			position: new THREE.Vector3(l.p[0], l.p[1], l.p[2]),
			color: srgb(l.c),
			brightness: l.b,
			range: l.r,
			world: l.k === 1,
			direction: l.d ? new THREE.Vector3(l.d[0], l.d[1], l.d[2]).normalize() : null,
			angle: l.a,
		}));
		// Roblox lights fade smoothly to nothing at their Range rather than by the inverse
		// square, so these use a 1/d falloff inside a window that closes at the range.
		for (let i = 0; i < CAL.pointLights; i++) {
			const light = new THREE.PointLight(0xffffff, 0, 10, 1);
			this.scene.add(light);
			this.pointLights.push(light);
		}
		this.spotLights = [];
		for (let i = 0; i < 4; i++) {
			const light = new THREE.SpotLight(0xffffff, 0, 10, 0.5, 0.6, 1);
			this.scene.add(light, light.target);
			this.spotLights.push(light);
		}
	}

	// The nearest lights to the camera (after scrolling) really light the scene.
	placeLights() {
		const cam = this.camera.position;
		const offset = this.world.position.x;
		const ranked = this.lights
			.map((l) => {
				const p = l.world ? l.position.clone().add(new THREE.Vector3(offset, 0, 0)) : l.position;
				return { l, p, d: p.distanceTo(cam) - l.range };
			})
			.sort((a, b) => a.d - b.d);
		const points = ranked.filter((e) => !e.l.direction);
		const spots = ranked.filter((e) => e.l.direction);
		const intensity = (l) => l.brightness * l.range * CAL.point;
		this.pointLights.forEach((light, i) => {
			const entry = points[i];
			light.intensity = entry ? intensity(entry.l) : 0;
			if (!entry) return;
			light.position.copy(entry.p);
			light.color.copy(entry.l.color);
			light.distance = entry.l.range;
		});
		this.spotLights.forEach((light, i) => {
			const entry = spots[i];
			light.intensity = entry ? intensity(entry.l) * 1.5 : 0;
			if (!entry) return;
			light.position.copy(entry.p);
			light.target.position.copy(entry.p).add(entry.l.direction);
			light.target.updateMatrixWorld();
			light.color.copy(entry.l.color);
			light.distance = entry.l.range;
			light.angle = Math.min(Math.PI / 2 - 0.01, ((entry.l.angle || 90) * Math.PI) / 360);
		});
	}

	setHeavens(list) {
		for (const sprite of this.sprites) {
			this.heavens.remove(sprite.object);
			sprite.texture.dispose();
			sprite.object.material.dispose();
		}
		this.sprites = [];
		for (const entry of list || []) {
			const width = Math.min(2048, Math.max(256, entry.res || 1024));
			const canvas = rasterize(entry.gui, width);
			const texture = new THREE.CanvasTexture(canvas);
			texture.colorSpace = THREE.SRGBColorSpace;
			texture.anisotropy = 4;
			const material = new THREE.SpriteMaterial({
				map: texture,
				transparent: true,
				depthWrite: false,
				depthTest: true,
				fog: false,
			});
			material.color.setScalar(entry.brightness ?? 1);
			const object = new THREE.Sprite(material);
			object.renderOrder = -10;
			const dir = new THREE.Vector3(entry.dir[0], entry.dir[1], entry.dir[2]).normalize();
			const k = CAL.heavenDistance / entry.dist;
			object.scale.set(entry.gui.size[0] * k, entry.gui.size[1] * k, 1);
			this.heavens.add(object);
			this.sprites.push({ object, texture, dir });
		}
	}

	applySky(s) {
		const u = this.sky.uniforms;
		const night = 1 - Math.min(1, Math.max(0, (s.brightness - 0.35) / 1.2));
		const sunDir = sunDirection(s.clock, s.latitude ?? 38);
		const moonDir = sunDir.clone().negate();
		u.uZenith.value.copy(linear([2, 3, 7]).multiplyScalar(0.6 + 2.4 * (1 - night)));
		u.uHorizon.value.copy(linear([9, 11, 18]).multiplyScalar(0.6 + 2.4 * (1 - night)));
		const atm = s.atmosphere;
		const skyLight = CAL.sky * (night > 0.5 ? CAL.nightSky : 1);
		u.uAir.value.copy(linear(atm.color));
		u.uDecay.value.copy(linear(atm.decay));
		u.uHaze.value = atm.haze;
		u.uGlare.value = atm.glare;
		u.uSunDir.value.copy(sunDir);
		u.uSunSize.value = s.sunSize ?? 14;
		u.uSunColor.value.copy(linear(atm.color)).multiplyScalar(1.6);
		u.uMoonDir.value.copy(moonDir);
		u.uMoonSize.value = s.moonSize ?? 0;
		u.uMoonColor.value.copy(linear([200, 206, 220]));
		u.uStars.value = Math.min(1, (s.stars ?? 0) / 3000) * night;
		u.uCover.value = s.clouds.cover;
		u.uCloudDensity.value = s.clouds.density;
		u.uCloudColor.value.copy(linear(s.clouds.color));
		u.uFlash.value = s.lightning || 0;
		u.uFlashColor.value.copy(linear(s.flashColor || [190, 196, 255]));
		u.uLight.value = skyLight;
		this.cloudWind = s.clouds.wind || [0, 0];
		this.skyState = s;

		// the fog colour is the horizon colour in the direction the camera faces
		const forward = new THREE.Vector3();
		this.camera.getWorldDirection(forward);
		const toward = Math.pow(
			(new THREE.Vector2(forward.x, forward.z).normalize().dot(new THREE.Vector2(sunDir.x, sunDir.z).normalize()) + 1) / 2,
			2,
		);
		const fogColor = linear(atm.decay).lerp(linear(atm.color), toward).multiplyScalar(skyLight);
		const cap = Math.min(0.995, 0.97 - 0.2 * (atm.offset ?? 0.25));
		this.scene.fog = new THREE.Fog(new THREE.Color(fogColor.x, fogColor.y, fogColor.z), atm.density * CAL.fog, cap);

		this.ambient.color.copy(srgb(s.ambient));
		this.ambient.intensity = CAL.ambient;
		this.hemi.color.copy(srgb(s.outdoor));
		this.hemi.groundColor.copy(srgb(s.outdoor, 0.3));
		this.hemi.intensity = CAL.outdoor;
		const lightDir = sunDir.y > -0.04 ? sunDir : moonDir;
		this.sun.position.copy(lightDir).multiplyScalar(1000);
		this.sun.color.copy(srgb(sunDir.y > -0.04 ? [255, 236, 214] : [190, 200, 255]));
		// Lighting.Brightness already carries the flash (Scenery/Sky adds it)
		this.sun.intensity = s.brightness * CAL.sun;
		this.shift.position.copy(lightDir).multiplyScalar(1000);
		this.shift.color.copy(srgb(s.shiftTop || [0, 0, 0]));
		this.shift.intensity = s.brightness * CAL.shift;

		this.bloom.strength = (s.bloom?.intensity ?? 0.8) * 0.75;
		this.bloom.radius = Math.min(1, (s.bloom?.size ?? 24) / 50);
		this.bloom.threshold = (s.bloom?.threshold ?? 1) * 0.9;
		this.final.uniforms.uExposure.value = CAL.exposure * Math.pow(2, s.exposure || 0);
		const grades = s.grades || [];
		this.final.uniforms.uGradeCount.value = Math.min(8, grades.length);
		grades.slice(0, 8).forEach((g, i) => {
			this.final.uniforms.uGrades.value[i].set(g.brightness || 0, g.contrast || 0, g.saturation || 0, 0);
			const tint = g.tint || [255, 255, 255];
			this.final.uniforms.uTints.value[i].set(tint[0] / 255, tint[1] / 255, tint[2] / 255);
		});
	}

	load(data) {
		this.data = data;
		this.loadParts(data.parts || []);
		this.loadLights(data.lights || []);
		this.speed = data.ride ? data.ride.speed : 0;
		if (data.sky) this.applySky(data.sky);
		this.setHeavens(data.heavens);
		this.frameIndex = -1;
	}

	setCamera(cam) {
		this.camera.position.set(cam.pos[0], cam.pos[1], cam.pos[2]);
		this.camera.fov = cam.fov || 70;
		this.camera.updateProjectionMatrix();
		this.camera.lookAt(cam.look[0], cam.look[1], cam.look[2]);
		this.camera.updateMatrixWorld();
		if (this.skyState) this.applySky(this.skyState);
	}

	// Ride time in seconds: scroll the landscape and step the sky timeline.
	setTime(t) {
		this.time = t;
		this.world.position.x = -this.speed * t;
		const frames = this.data && this.data.frames;
		if (frames && frames.length) {
			let index = 0;
			while (index + 1 < frames.length && frames[index + 1].t <= t) index++;
			if (index !== this.frameIndex) {
				this.frameIndex = index;
				const frame = frames[index];
				if (frame.sky) this.applySky(frame.sky);
				if (frame.heavens) this.setHeavens(frame.heavens);
			}
		}
	}

	render() {
		const wind = this.cloudWind || [0, 0];
		this.sky.uniforms.uCloudOffset.value.set(-wind[0] * this.time, -wind[1] * this.time);
		for (const sprite of this.sprites) {
			sprite.object.position.copy(this.camera.position).addScaledVector(sprite.dir, CAL.heavenDistance);
		}
		this.placeLights();
		this.composer.render();
	}
}
