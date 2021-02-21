
const assert = require('assert');


module.exports = function (generated, output) {
    const { ports = [], flags, logs : expectedLogs = '' } = output;
    let actualLogs = ''
    generated._debugLog = str => {
        actualLogs += str + '\n';
        // If we do not expect logs print them for debugging.
        if (expectedLogs === '') {
            console.log(str);
        }
    }
    if (!Object.prototype.hasOwnProperty.call(generated, '_another_elm')) {
        Date.now = () => 0;
    }
    generated._randSeed = () => 0;
    const app = generated.Elm.Main.init(flags !== undefined ? { flags } : undefined);
    let portEventIndex = 0;

    function sendIfNextEventSubscription() {
        if (portEventIndex < ports.length) {
            const nextEvent = ports[portEventIndex];
            const [nextType, nextPortName, nextData] = nextEvent;
            if (nextType === "subscription") {
                assert(
                    app.ports[nextPortName] !== undefined,
                    `Port event ${portEventIndex + 1} calls for sending ${nextData} to port ${nextPortName} but the app does not have such a port.`,
                );
                assert(
                    app.ports[nextPortName].send !== undefined,
                    `Port event ${portEventIndex + 1} calls for sending ${nextData} to port ${nextPortName} but that is a command port.`,
                );
                portEventIndex += 1;
                app.ports[nextPortName].send(nextData);
            }
        }
    }

    if (app.ports !== undefined) {
        for (const portName of Object.keys(app.ports)) {
            if (app.ports[portName].subscribe !== undefined) {
                app.ports[portName].subscribe(data => {
                    assert(
                        portEventIndex < ports.length,
                        `There should be exactly "${ports.length}" port events but this is event ${portEventIndex + 1}.`,
                    );
                    const [type, expectedName, expectedData] = ports[portEventIndex];
                    assert(
                        type === "command",
                        `Port event ${portEventIndex} should be a ${type} but command ${portName} received (with value ${data}).`,
                    );
                    assert(
                        expectedName === portName,
                        `Port event ${portEventIndex} should be command ${expectedName} but command ${portName} received (with value ${data}).`,
                    );
                    assert.deepStrictEqual(
                        data,
                        expectedData,
                        `Wrong data sent to port ${portName} during port event ${portEventIndex + 1}`,
                    );
                    portEventIndex += 1;
                    sendIfNextEventSubscription();
                })
            }
        }
    }

    sendIfNextEventSubscription();

    process.on('exit', () => {
        assert.strictEqual(
            portEventIndex, ports.length,
            `There have been ${portEventIndex} port events but should have been exactly ${ports.length} port events.`,
        );
        assert.strictEqual(
            actualLogs, expectedLogs,
            `Unexpected logs`,
        );
    });

}

