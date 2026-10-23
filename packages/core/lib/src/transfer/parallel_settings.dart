/// How many files of one transfer travel at the same time. A few is
/// enough to hide the pause between many small files; more only makes
/// them compete for the same Wi-Fi.
const int defaultParallelFiles = 3;

/// The most connections a receiver or sender lets one transfer hold open,
/// so a paired device cannot ask for a thousand files at once.
const int maxParallelFilesPerTransfer = 8;
