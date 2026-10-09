/// The authenticated WebSocket that carries control messages.
const controlChannelPath = '/v1/control';

/// File [fileIndex] of an accepted offer: the phone uploads with PUT and
/// downloads with GET.
String transferFilePath(String transferId, int fileIndex) =>
    '/v1/transfers/$transferId/$fileIndex';
