// Background: thin concentric rings radiating from the logo's circle, with a slowly
// shifting greyscale camo pattern colouring the rings. Drawn with WebGL; falls back to
// the plain dark background if WebGL isn't available.
(function () {
  // Where the circle's centre sits inside logo.svg (viewBox 34 12 332 378, circle at 200,168)
  var VB = { x: 34, y: 12, w: 332, h: 378 }, CIRCLE = { x: 200, y: 168 };
  var RING_PX = 1.6, PERIOD_PX = 5.5, SPEED_PX = 2.25; // CSS px, px per second

  var center = { x: window.innerWidth / 2, y: 180 };
  // Login page: the header's background logo. Account console: the logo in the top bar, which
  // React renders after this script runs, so frame() keeps looking it up.
  function locate() {
    var el = document.getElementById("kc-header-wrapper") ||
      document.querySelector(".pf-v5-c-masthead__brand img, .pf-v5-c-brand");
    if (!el || !el.getBoundingClientRect().width) return false;
    var r = el.getBoundingClientRect();
    var s = Math.min(r.width / VB.w, r.height / VB.h); // background-size: contain
    var ox = r.left + (r.width - VB.w * s) / 2, oy = r.top + (r.height - VB.h * s) / 2;
    center.x = ox + (CIRCLE.x - VB.x) * s;
    center.y = oy + (CIRCLE.y - VB.y) * s;
    return true;
  }

  function start() {
    var canvas = document.createElement("canvas");
    canvas.id = "cc-rings";
    document.body.insertBefore(canvas, document.body.firstChild);
    var gl = canvas.getContext("webgl", { antialias: false, premultipliedAlpha: false });
    if (!gl) { canvas.remove(); return; }

    var vs = "attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}";
    var fs = [
      "precision highp float;",
      "uniform vec2 res;uniform vec2 ctr;uniform float t;uniform float dpr;",
      "uniform float ring;uniform float period;uniform float speed;uniform vec3 mouse;",
      // 3D value noise + fbm
      "float h(vec3 p){p=fract(p*0.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}",
      "float n(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);",
      " return mix(mix(mix(h(i),h(i+vec3(1,0,0)),f.x),mix(h(i+vec3(0,1,0)),h(i+vec3(1,1,0)),f.x),f.y),",
      "            mix(mix(h(i+vec3(0,0,1)),h(i+vec3(1,0,1)),f.x),mix(h(i+vec3(0,1,1)),h(i+vec3(1,1,1)),f.x),f.y),f.z);}",
      "float fbm(vec3 p){float v=0.,a=.5;for(int k=0;k<4;k++){v+=a*n(p);p*=2.03;a*=.5;}return v;}",
      "void main(){",
      " vec2 px=vec2(gl_FragCoord.x,res.y-gl_FragCoord.y)/dpr;",       // CSS px, top-left origin
      " float d=distance(px,ctr);",
      // mouse: the rings swirl around the cursor (pushed out on one side, pulled in on the other)
      // and a small second set of rings radiates from the cursor itself (mouse.z = strength 0..1)
      " vec2 mq=px-mouse.xy;float md=length(mq);",
      " float bump=mouse.z*smoothstep(115.,15.,md);",
      " float sw=bump*1.1;mat2 SW=mat2(cos(sw),-sin(sw),sin(sw),cos(sw));",
      " float dw=distance(mouse.xy+SW*mq,ctr);",
      " float ph=mod(dw-t*speed,period);",
      " float line=1.-smoothstep(ring*.5-.6,ring*.5+.6,abs(ph-period*.5));", // anti-aliased thin ring
      " float ph2=mod(md-t*speed*2.,period);",
      " float line2=1.-smoothstep(ring*.5-.6,ring*.5+.6,abs(ph2-period*.5));",
      " float inner=mouse.z*smoothstep(55.,10.,md);",
      " line=mix(line,line2,inner);",
      // camo: posterised noise; patches are the same size everywhere, stretched along the rings,
      // and drift slowly outward with time
      " vec3 s=vec3(px*.0045,dw*.012-t*.045)+vec3(sin(t*.06),cos(t*.045),0.)*.9;",
      " float c=fbm(s);",
      " float lv=floor(clamp((c-.25)*2.2,0.,.999)*4.);",              // 4 camo tones
      " float g=mix(.16,.62,lv/3.)+bump*.38;",
      " float fade=1.-smoothstep(120.,max(res.x,res.y)/dpr*.75,d);",   // fade out away from the logo
      " vec3 bg=vec3(.043);",
      " gl_FragColor=vec4(mix(bg,vec3(g),line*(.35+.65*fade)),1.);",
      "}"
    ].join("\n");
    function sh(type, src) { var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); return s; }
    var prog = gl.createProgram();
    gl.attachShader(prog, sh(gl.VERTEX_SHADER, vs));
    gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, fs));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) { canvas.remove(); return; }
    gl.useProgram(prog);
    var buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    var loc = gl.getAttribLocation(prog, "p");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    var u = {};
    ["res", "ctr", "t", "dpr", "ring", "period", "speed", "mouse"].forEach(function (k) { u[k] = gl.getUniformLocation(prog, k); });

    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    function size() {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.round(window.innerWidth * dpr);
      canvas.height = Math.round(window.innerHeight * dpr);
      gl.viewport(0, 0, canvas.width, canvas.height);
      locate();
    }
    size();
    window.addEventListener("resize", size);
    window.addEventListener("scroll", locate, { passive: true });

    var target = { x: -9999, y: -9999, on: 0 }, mouse = { x: -9999, y: -9999, z: 0 };
    window.addEventListener("pointermove", function (e) {
      if (mouse.z < 0.01) { mouse.x = e.clientX; mouse.y = e.clientY; }
      target.x = e.clientX; target.y = e.clientY; target.on = 1;
    }, { passive: true });
    document.addEventListener("pointerleave", function () { target.on = 0; });
    window.addEventListener("blur", function () { target.on = 0; });

    var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    var t0 = performance.now();
    var frames = 0, found = false;
    function frame(now) {
      if (!found || frames++ % 30 === 0) found = locate();
      gl.uniform2f(u.res, canvas.width, canvas.height);
      gl.uniform2f(u.ctr, center.x, center.y);
      gl.uniform1f(u.t, still ? 0 : (now - t0) / 1000);
      gl.uniform1f(u.dpr, dpr);
      gl.uniform1f(u.ring, RING_PX);
      gl.uniform1f(u.period, PERIOD_PX);
      gl.uniform1f(u.speed, SPEED_PX);
      mouse.x += (target.x - mouse.x) * 0.08;
      mouse.y += (target.y - mouse.y) * 0.08;
      mouse.z += (target.on - mouse.z) * 0.05;
      gl.uniform3f(u.mouse, mouse.x, mouse.y, still ? 0 : mouse.z);
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      if (!still) requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
  window.addEventListener("load", locate);
})();
