/*
	Rasterizes an exported BillboardGui tree (see .lune/preview.luau) onto a 2D canvas,
	following Roblox's layout rules closely enough for sky objects:

	  * Size and Position are UDim2 (scale of the parent's size plus pixel offset);
	    AnchorPoint shifts the element by a share of its own size
	  * Rotation turns the element and everything inside it about its centre, clockwise
	  * UICorner rounds the corners; its scale is a share of the shorter side, and a
	    radius past half that side makes a circle or a capsule
	  * UIGradient multiplies the background colour and transparency along a line
	    turned clockwise by its Rotation (0 is left to right, 90 top to bottom) and
	    shifted by its Offset; outside 0..1 it clamps to the end keypoints
	  * siblings draw in ZIndex order, then in tree order

	Node shape: { c, n, s:[xs,xo,ys,yo], p:[xs,xo,ys,yo], a:[ax,ay], r, bc:[r,g,b], bt, z, v,
	              corner:[scale, offset]?, grad:{ c:[[t,r,g,b]..], tr:[[t,v]..], r, o:[x,y] }?, ch:[..] }
	Colours are 0..255 sRGB, as Roblox stores them.
*/

const GRADIENT_STEPS = 48;

function sampleColor(keys, t) {
	if (t <= keys[0][0]) return keys[0].slice(1);
	for (let i = 1; i < keys.length; i++) {
		const b = keys[i];
		if (t <= b[0]) {
			const a = keys[i - 1];
			const k = (t - a[0]) / Math.max(b[0] - a[0], 1e-6);
			return [a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k];
		}
	}
	return keys[keys.length - 1].slice(1);
}

function sampleNumber(keys, t) {
	if (t <= keys[0][0]) return keys[0][1];
	for (let i = 1; i < keys.length; i++) {
		const b = keys[i];
		if (t <= b[0]) {
			const a = keys[i - 1];
			const k = (t - a[0]) / Math.max(b[0] - a[0], 1e-6);
			return a[1] + (b[1] - a[1]) * k;
		}
	}
	return keys[keys.length - 1][1];
}

function roundedRect(ctx, x, y, w, h, radius) {
	const r = Math.max(0, Math.min(radius, Math.min(w, h) / 2));
	ctx.beginPath();
	if (r <= 0.01) {
		ctx.rect(x, y, w, h);
		return;
	}
	ctx.moveTo(x + r, y);
	ctx.lineTo(x + w - r, y);
	ctx.arc(x + w - r, y + r, r, -Math.PI / 2, 0);
	ctx.lineTo(x + w, y + h - r);
	ctx.arc(x + w - r, y + h - r, r, 0, Math.PI / 2);
	ctx.lineTo(x + r, y + h);
	ctx.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI);
	ctx.lineTo(x, y + r);
	ctx.arc(x + r, y + r, r, Math.PI, Math.PI * 1.5);
	ctx.closePath();
}

/*
	A UIGradient as a canvas gradient in the element's own (unrotated) box. Roblox maps
	the 0..1 sequence across the element along the rotated direction; the span is the
	box's extent along that direction, so 0 and 1 land on opposite corners or edges.
*/
function gradientFill(ctx, grad, base, alpha, w, h) {
	const angle = ((grad.r || 0) * Math.PI) / 180;
	const dx = Math.cos(angle);
	const dy = Math.sin(angle);
	const ox = (grad.o ? grad.o[0] : 0) * w;
	const oy = (grad.o ? grad.o[1] : 0) * h;
	const half = (Math.abs(dx) * w + Math.abs(dy) * h) / 2;
	const cx = w / 2 + ox;
	const cy = h / 2 + oy;
	const g = ctx.createLinearGradient(cx - dx * half, cy - dy * half, cx + dx * half, cy + dy * half);
	const colors = grad.c && grad.c.length ? grad.c : [[0, 255, 255, 255], [1, 255, 255, 255]];
	const trans = grad.tr && grad.tr.length ? grad.tr : [[0, 0], [1, 0]];
	for (let i = 0; i <= GRADIENT_STEPS; i++) {
		const t = i / GRADIENT_STEPS;
		const c = sampleColor(colors, t);
		const a = alpha * (1 - sampleNumber(trans, t));
		const r = Math.round((base[0] * c[0]) / 255);
		const gg = Math.round((base[1] * c[1]) / 255);
		const b = Math.round((base[2] * c[2]) / 255);
		g.addColorStop(t, `rgba(${r},${gg},${b},${Math.max(0, Math.min(1, a)).toFixed(4)})`);
	}
	return g;
}

function drawNode(ctx, node, parentW, parentH) {
	if (node.v === false) return;
	const s = node.s || [0, 0, 0, 0];
	const p = node.p || [0, 0, 0, 0];
	const a = node.a || [0, 0];
	const w = parentW * s[0] + s[1];
	const h = parentH * s[2] + s[3];
	const x = parentW * p[0] + p[1] - w * a[0];
	const y = parentH * p[2] + p[3] - h * a[1];
	ctx.save();
	ctx.translate(x + w / 2, y + h / 2);
	if (node.r) ctx.rotate((node.r * Math.PI) / 180);
	ctx.translate(-w / 2, -h / 2);
	const alpha = 1 - (node.bt ?? 1);
	if (node.c === 'Frame' && alpha > 0.0005 && w > 0 && h > 0) {
		const radius = node.corner ? Math.min(w, h) * node.corner[0] + node.corner[1] : 0;
		roundedRect(ctx, 0, 0, w, h, radius);
		const base = node.bc || [255, 255, 255];
		if (node.grad) {
			ctx.fillStyle = gradientFill(ctx, node.grad, base, alpha, w, h);
		} else {
			ctx.fillStyle = `rgba(${base[0]},${base[1]},${base[2]},${alpha.toFixed(4)})`;
		}
		ctx.fill();
	}
	if (node.k) {
		ctx.beginPath();
		ctx.rect(0, 0, w, h);
		ctx.clip();
	}
	const children = (node.ch || []).map((child, i) => ({ child, i }));
	children.sort((m, n) => (m.child.z ?? 1) - (n.child.z ?? 1) || m.i - n.i);
	for (const { child } of children) drawNode(ctx, child, w, h);
	ctx.restore();
}

// Draws `gui` (an exported BillboardGui) into a new canvas `width` pixels wide.
export function rasterize(gui, width) {
	const aspect = gui.size[1] / gui.size[0];
	const canvas = document.createElement('canvas');
	canvas.width = width;
	canvas.height = Math.max(1, Math.round(width * aspect));
	const ctx = canvas.getContext('2d');
	ctx.clearRect(0, 0, canvas.width, canvas.height);
	const children = (gui.ch || []).map((child, i) => ({ child, i }));
	children.sort((m, n) => (m.child.z ?? 1) - (n.child.z ?? 1) || m.i - n.i);
	for (const { child } of children) drawNode(ctx, child, canvas.width, canvas.height);
	return canvas;
}
