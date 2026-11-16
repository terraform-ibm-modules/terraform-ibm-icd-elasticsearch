// Preloaded into Kibana (NODE_OPTIONS=--require) by kibana-start.sh. Resolves the Elasticsearch hostname as the
// Private Path endpoint hostname, so Kibana connects through Private Path while still sending the real hostname as
// SNI and verifying the certificate against it. The endpoint is resolved on every lookup (not pinned to one IP), so a
// change of the Code Engine side's VPE gateway is picked up on the next connection. Every other hostname is unchanged.
const dns = require('dns');

const esHostname = process.env.ES_HOSTNAME;
const privatePathEndpoint = process.env.PRIVATE_PATH_ENDPOINT;
const lookup = dns.lookup;

dns.lookup = function (hostname, ...args) {
  return lookup.call(this, hostname === esHostname ? privatePathEndpoint : hostname, ...args);
};
