const CONFIG = {
  baseURI: '/flood',
  dbCleanInterval: 1000 * 60 * 60,
  dbPath: '/data/flood/db',
  floodServerHost: '127.0.0.1',
  floodServerPort: 3000,
  floodServerProxy: 'http://127.0.0.1',
  maxHistoryStates: 30,
  pollInterval: 1000 * 5,
  torrentClientPollInterval: 1000 * 2,
  secret: 'flood',
  scgi: {
    host: 'localhost',
    port: 5000,
    socket: true,
    socketPath: '/tmp/rtorrent_scgi.sock'
  },
  ssl: false,
  sslKey: '/config/key.pem',
  sslCert: '/config/cert.pem',
};

module.exports = CONFIG;
