#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

NVM_DIR="${NVM_DIR:-/usr/local/share/nvm}"
INSTALL_PATH=/usr/local/share/typescript-language-server

outside_nvm() {
	case "$(readlink -f "$(command -v typescript-language-server)")" in
	"${NVM_DIR}"/*) return 1 ;;
	esac
}

finds_fallback_tsserver() {
	node -e "
		const path = require('node:path');
		const server = '${INSTALL_PATH}/lib/node_modules/typescript-language-server/lib/cli.mjs';
		const typescript = require('node:module').createRequire(server).resolve('typescript');
		require('node:fs').accessSync(path.join(path.dirname(typescript), 'tsserver.js'));
	"
}

publishes_diagnostics() {
	workspace="$(mktemp -d)" &&
		node - "$workspace" <<-'EOF'
			const { spawn } = require('node:child_process');
			const workspace = process.argv[2];
			const uri = 'file://' + workspace + '/main.ts';
			const server = spawn('typescript-language-server', ['--stdio'], { cwd: workspace, stdio: ['pipe', 'pipe', 'inherit'] });
			const send = (message) => {
			  const body = Buffer.from(JSON.stringify({ jsonrpc: '2.0', ...message }));
			  server.stdin.write('Content-Length: ' + body.length + '\r\n\r\n');
			  server.stdin.write(body);
			};
			let buffered = Buffer.alloc(0);
			server.stdout.on('data', (chunk) => {
			  buffered = Buffer.concat([buffered, chunk]);
			  for (;;) {
			    const headerEnd = buffered.indexOf('\r\n\r\n');
			    if (headerEnd < 0) return;
			    const length = Number(/Content-Length: *(\d+)/i.exec(buffered.subarray(0, headerEnd).toString())[1]);
			    if (buffered.length < headerEnd + 4 + length) return;
			    const message = JSON.parse(buffered.subarray(headerEnd + 4, headerEnd + 4 + length).toString());
			    buffered = buffered.subarray(headerEnd + 4 + length);
			    if (message.id !== undefined && message.method !== undefined) {
			      send({ id: message.id, result: null });
			    } else if (message.method === 'textDocument/publishDiagnostics' && message.params.uri === uri && message.params.diagnostics.length > 0) {
			      console.log(message.params.diagnostics[0].message);
			      process.exit(0);
			    }
			  }
			});
			send({ id: 1, method: 'initialize', params: { processId: process.pid, rootUri: 'file://' + workspace, capabilities: { textDocument: { publishDiagnostics: {} } } } });
			send({ method: 'initialized', params: {} });
			send({ method: 'textDocument/didOpen', params: { textDocument: { uri: uri, languageId: 'typescript', version: 1, text: 'const n: number = "x";\n' } } });
			setTimeout(() => { console.error('no diagnostics before timeout'); process.exit(1); }, 60000);
		EOF
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/typescript-language-server &&
		! test -w "${INSTALL_PATH}/bin/typescript-language-server"
}

survives_node_switch() {
	# shellcheck source=/dev/null
	. "${NVM_DIR}/nvm.sh" &&
		nvm install 20 >/dev/null &&
		nvm use 20 >/dev/null &&
		test "$(node -v | cut -d. -f1)" = v20 &&
		typescript-language-server --version
}

check 'check if typescript-language-server exists' bash -c "command -v typescript-language-server"
check 'check if typescript-language-server runs' bash -c "typescript-language-server --version"
check 'check if a fallback tsserver resolves from the server tree' finds_fallback_tsserver
check 'check if the server publishes diagnostics in a workspace with no typescript' publishes_diagnostics
check 'check if typescript-language-server lives outside the nvm version directories' outside_nvm
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
# Keep last: repoints nvm's "current" symlink for every later check.
check 'check if typescript-language-server survives a node version switch' survives_node_switch
reportResults
