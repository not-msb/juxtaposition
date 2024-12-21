const canvas = document.getElementById("app");
const ctx = canvas.getContext("2d");

let exports;
let buffer;
let view;

let width;
let height;

const importObjects = {
    env: {
        print: (result) => { console.log(`The result is ${result}`); },
        width: width,
    }
};


WebAssembly.instantiateStreaming(fetch("./dist/main.wasm"), importObjects).then(w => {
    exports = w.instance.exports;
    exports.init();

    buffer = new Uint8ClampedArray(exports.memory.buffer);
    view = new DataView(exports.memory.buffer);

    width = view.getUint32(exports.width, true);
    height = view.getUint32(exports.height, true);
    canvas.width = width;
    canvas.height = height;

    window.requestAnimationFrame(draw);
});

function draw() {
    exports.draw();

    const slice = buffer.slice(exports.image, exports.image + 4*width*height);
    const image = new ImageData(slice, width, height);
    ctx.putImageData(image, 0, 0);

    window.requestAnimationFrame(draw);
}
