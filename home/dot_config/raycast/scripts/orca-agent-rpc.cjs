const path = require('node:path');
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => { input += chunk });
process.stdin.on('end', async () => {
  try {
    const request = JSON.parse(input);
    const {RuntimeClient} = require(path.join(request.resources, 'app.asar.unpacked/out/cli/runtime-client.js'));
    const client = new RuntimeClient(request.userData, request.timeoutMs, null, request.environment);
    const response = await client.call(request.method, request.params);
    process.stdout.write(JSON.stringify(response));
  } catch (error) {
    const response = error.response?.ok === false ? error.response : {
      ok: false, transportError: true, error: {message: 'Selected paired Orca server unavailable or incompatible'}
    };
    process.stdout.write(JSON.stringify(response));
    process.exitCode = 1;
  }
});
