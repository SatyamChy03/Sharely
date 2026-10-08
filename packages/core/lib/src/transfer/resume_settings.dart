/// Names the byte a resumed upload or download continues from.
const resumeOffsetHeader = 'x-sharely-offset';

/// How long a transfer may sit without moving a byte before it is given up.
/// Long enough to walk back into Wi-Fi range; short enough to notice a
/// laptop that was switched off.
const defaultResumeWindow = Duration(minutes: 3);

/// A data connection silent for this long is treated as broken, since a
/// peer that lost Wi-Fi never says goodbye.
const defaultDataIdleTimeout = Duration(seconds: 20);

/// Where the sender asks how much of a file the receiver already holds.
String transferOffsetPath(String transferId, int fileIndex) =>
    '/v1/transfers/$transferId/$fileIndex/offset';
