const canvas = document.getElementById("app");
const ctx = canvas.getContext("2d");

let exports;
let width;
let height;

const Mode = Object.freeze({
    flat: 0,
    wireframe: 1,
});

const importObjects = {
    env: {
        print: (result) => { console.log(`The result is ${result}`); },
    }
};


WebAssembly.instantiateStreaming(fetch("./dist/main.wasm"), importObjects).then(w => {
    exports = w.instance.exports;

    const buffer = new Uint8ClampedArray(exports.memory.buffer);
    const view = new DataView(exports.memory.buffer);

    width = view.getUint32(exports.wasm_width, true);
    height = view.getUint32(exports.wasm_height, true);
    canvas.width = width;
    canvas.height = height;

    console.log("Starting Zig init");
    exports.init();
    console.log("Ending Zig init");
    window.requestAnimationFrame(draw);
});

function draw() {
    exports.draw();

    const buffer = new Uint8ClampedArray(exports.memory.buffer);
    const slice = buffer.slice(exports.image, exports.image + 4*width*height);
    const image = new ImageData(slice, width, height);
    ctx.putImageData(image, 0, 0);

    window.requestAnimationFrame(draw);
}
