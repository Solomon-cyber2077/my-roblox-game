/*
	The sky dome: an approximation of what Roblox draws behind the world with a Sky,
	an Atmosphere and dynamic Clouds. It is a stand-in for judging colours and layout,
	not a copy of the engine's shader:

	  * the skybox at night is a dark gradient with procedural stars (Sky.StarCount)
	  * a deck of clouds at a fixed height drifts with the wind (Clouds.Cover, Density,
	    Color; Workspace.GlobalWind)
	  * the Atmosphere hazes the sky from the horizon up (Haze), in its Color toward the
	    sun and its Decay away from it, with Glare around the sun
	  * the engine's sun and moon discs (SunAngularSize, MoonAngularSize; 0 hides one)
	  * lightning brightens the clouds and the haze

	Sky objects the game draws itself (the moon, horizon glows, bolts) are BillboardGuis,
	drawn by viewer.js as sprites in front of this dome.
*/

import * as THREE from 'three';

const vertexShader = /* glsl */ `
varying vec3 vDir;
void main() {
	vDir = position;
	vec4 p = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
	gl_Position = p.xyww;
}`;

const fragmentShader = /* glsl */ `
precision highp float;
varying vec3 vDir;
uniform vec3 uZenith;
uniform vec3 uHorizon;
uniform vec3 uAir;
uniform vec3 uDecay;
uniform float uHaze;
uniform float uGlare;
uniform vec3 uSunDir;
uniform float uSunSize;
uniform vec3 uSunColor;
uniform vec3 uMoonDir;
uniform float uMoonSize;
uniform vec3 uMoonColor;
uniform float uStars;
uniform float uCover;
uniform float uCloudDensity;
uniform vec3 uCloudColor;
uniform vec2 uCloudOffset;
uniform float uFlash;
uniform vec3 uFlashColor;
uniform float uLight;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

void main() {
	vec3 d = normalize(vDir);
	float el = d.y;

	// the skybox: a dark gradient, stars where the air is clear
	vec3 col = mix(uHorizon, uZenith, pow(clamp(el, 0.0, 1.0), 0.45));
	if (el > 0.0 && uStars > 0.0) {
		vec3 g = d * 260.0;
		vec3 cell = floor(g);
		vec3 f = fract(g) - 0.5;
		float h = hash13(cell);
		float on = step(1.0 - uStars * 0.06, h);
		float twinkle = hash13(cell + 7.0);
		float star = on * smoothstep(0.14, 0.0, length(f)) * (0.25 + 0.5 * twinkle);
		col += vec3(0.85, 0.88, 1.0) * star * smoothstep(0.0, 0.3, el);
	}

	// the cloud deck
	float cloudA = 0.0;
	if (el > 0.003 && uCover > 0.0) {
		float t = 2600.0 / el;
		vec2 pos = (d.xz * t + uCloudOffset) / 3400.0;
		float n = fbm(pos);
		float n2 = fbm(pos * 2.7 + 3.1);
		float field = n * 0.8 + n2 * 0.3;
		float threshold = 0.92 - uCover * 0.62;
		float c = smoothstep(threshold - 0.06, threshold + 0.22, field);
		float fade = exp(-t / 70000.0) * smoothstep(0.0, 0.05, el);
		cloudA = clamp(c * (0.8 + 0.4 * uCloudDensity), 0.0, 1.0) * fade;
		float thick = smoothstep(0.25, 1.0, c);
		vec3 cloud = uCloudColor * mix(1.2, 0.55, thick);
		float moonward = pow(max(dot(d, uMoonDir), 0.0), 20.0);
		cloud += uMoonColor * moonward * (1.0 - thick) * 0.5;
		// the flash lights the deck unevenly (Clouds.Color already carries its colour)
		cloud *= 1.0 + uFlash * 1.5 * n2;
		col = mix(col, cloud, cloudA);
	}

	// the atmosphere: haze from the horizon up, Color toward the sun and Decay away
	vec2 hd = normalize(d.xz + vec2(1e-5));
	vec2 hs = normalize(uSunDir.xz + vec2(1e-5));
	float toward = pow(dot(hd, hs) * 0.5 + 0.5, 2.0);
	vec3 air = mix(uDecay, uAir, toward);
	float spread = 0.03 + 0.1 * uHaze;
	float haze = el <= 0.0 ? 1.0 : clamp(exp(-el / spread) * (0.85 + 0.05 * uHaze), 0.0, 1.0);
	col = mix(col, air, haze);

	// the sun, its glare, and the engine's moon
	float sd = dot(d, uSunDir);
	float sunR = cos(radians(uSunSize * 0.22));
	col += uSunColor * smoothstep(sunR - 0.0004, sunR, sd) * 5.0 * smoothstep(-0.03, 0.0, uSunDir.y);
	col += uSunColor * pow(max(sd, 0.0), 10.0) * uGlare * 0.6 * smoothstep(-0.25, 0.0, uSunDir.y);
	if (uMoonSize > 0.0) {
		float md = dot(d, uMoonDir);
		float moonR = cos(radians(uMoonSize * 0.22));
		col = mix(col, uMoonColor * 1.5, smoothstep(moonR - 0.0003, moonR, md) * (1.0 - cloudA * 0.85));
		col += uMoonColor * pow(max(md, 0.0), 400.0) * 0.2;
	}

	col += uFlashColor * uFlash * 0.15;
	gl_FragColor = vec4(col * uLight, 1.0);
}`;

function linear(rgb) {
	const c = new THREE.Color();
	c.setRGB(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, THREE.SRGBColorSpace);
	return new THREE.Vector3(c.r, c.g, c.b);
}

export function createSky() {
	const uniforms = {
		uZenith: { value: new THREE.Vector3() },
		uHorizon: { value: new THREE.Vector3() },
		uAir: { value: new THREE.Vector3() },
		uDecay: { value: new THREE.Vector3() },
		uHaze: { value: 1 },
		uGlare: { value: 0 },
		uSunDir: { value: new THREE.Vector3(0, 1, 0) },
		uSunSize: { value: 14 },
		uSunColor: { value: new THREE.Vector3(1, 0.8, 0.6) },
		uMoonDir: { value: new THREE.Vector3(0, -1, 0) },
		uMoonSize: { value: 0 },
		uMoonColor: { value: new THREE.Vector3(0.8, 0.85, 1) },
		uStars: { value: 0.5 },
		uCover: { value: 0.5 },
		uCloudDensity: { value: 0.5 },
		uCloudColor: { value: new THREE.Vector3(0.2, 0.2, 0.25) },
		uCloudOffset: { value: new THREE.Vector2() },
		uFlash: { value: 0 },
		uFlashColor: { value: new THREE.Vector3(0.75, 0.78, 1) },
		uLight: { value: 1 },
	};
	const material = new THREE.ShaderMaterial({
		uniforms,
		vertexShader,
		fragmentShader,
		side: THREE.BackSide,
		depthWrite: false,
		depthTest: false,
		fog: false,
	});
	const mesh = new THREE.Mesh(new THREE.SphereGeometry(1, 96, 48), material);
	mesh.frustumCulled = false;
	mesh.renderOrder = -1000;
	mesh.scale.setScalar(50000);
	mesh.onBeforeRender = (_renderer, _scene, camera) => {
		mesh.position.copy(camera.position);
		mesh.updateMatrixWorld();
	};
	return { mesh, uniforms, linear };
}

export { linear };
