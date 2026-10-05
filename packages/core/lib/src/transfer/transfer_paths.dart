/// The authenticated WebSocket that carries control messages.
const controlChannelPath = '/v1/control';

/// Where the sender uploads file [fileIndex] of an accepted offer.
String transferFilePath(String transferId, int fileIndex) =>
    '/v1/transfers/$transferId/$fileIndex';
