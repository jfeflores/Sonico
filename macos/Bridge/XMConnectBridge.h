#pragma once
#include <mdr-c/Headphones.h>
#include <mdr-bt/ConnectionMacOS.h>

// Clang's Swift importer cannot represent these composed C macros.
static inline MDRHeadphonesInitFlags xmDefaultInitFlags(void)
{
    return MDR_HEADPHONES_INIT_DEFAULT;
}
static inline MDRHeadphonesSyncFlags xmDefaultSyncFlags(void)
{
    return MDR_HEADPHONES_SYNC_DEFAULT;
}
static inline MDRHeadphonesSyncFlags xmPlaybackSyncFlags(void)
{
    return MDR_HEADPHONES_SYNC_PLAYBACK;
}
