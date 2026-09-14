
#ifdef VERSION_STRING
    #define VER     " " VERSION_STRING
#else
    #define VER     ""
#endif

#ifdef ENABLE_FEAT_N7SIX
    #ifndef AUTHOR_STRING_2
        #define AUTHOR_STRING_2 "N7SIX"
    #endif
    #ifndef VERSION_STRING_2
        #define VERSION_STRING_2 "v7.6.10"
    #endif
    #ifndef EDITION_STRING
        #define EDITION_STRING "Custom"
    #endif
    #ifndef AUTHOR_STRING
        #define AUTHOR_STRING AUTHOR_STRING_2
    #endif
    const char Version[]      = AUTHOR_STRING_2 " " VERSION_STRING_2;
    const char Edition[]      = EDITION_STRING;
#else
    #ifndef AUTHOR_STRING
        #define AUTHOR_STRING "EGZUMER"
    #endif
    const char Version[]      = AUTHOR_STRING VER;
#endif

const char UART_Version[] = "UV-K5 Firmware, " AUTHOR_STRING VER "\r\n";

const char BuildDate[] = __DATE__;
const char BuildTime[] = __TIME__;
const char BuildCommit[] = "N/A";
