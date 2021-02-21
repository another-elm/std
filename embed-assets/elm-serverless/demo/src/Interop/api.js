const elmServerless = require('../../../src-bridge');

const {
  Elm
} = require('./API.elm');

const app = Elm.Interop.API.init();

// Random numbers through a port.
if (app.ports != null && app.ports.requestRand != null) {
  app.ports.requestRand.subscribe(args => {
    const connectionId = args[0];
    const interopSeq = args[1];
    app.ports.respondRand.send([connectionId, interopSeq, Math.random()]);
  });
}

// Create the serverless handler with the ports.
module.exports.handler = elmServerless.httpApi({
  app
});
