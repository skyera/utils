" Syntax highlighting for NVIDIA Compute Sanitizer text logs.
" Output format: https://docs.nvidia.com/compute-sanitizer/ComputeSanitizer/
if exists("b:current_syntax")
    finish
endif

syntax match computeSanitizerLine '^=\{8,}.*$' contains=computeSanitizerPrefix,computeSanitizerHeader,computeSanitizerNumber,computeSanitizerAddress,computeSanitizerLocation,computeSanitizerThread,computeSanitizerError,computeSanitizerWarning,computeSanitizerSummary,computeSanitizerSuccess
syntax match computeSanitizerPrefix '^=\{8,}' contained
syntax match computeSanitizerHeader '\<COMPUTE-SANITIZER\>' contained
syntax match computeSanitizerNumber '\<\d\+\>' contained
syntax match computeSanitizerAddress '\<0x\x\+\>' contained
syntax match computeSanitizerLocation '[[:alnum:]_./\\:-]\+\.\%(cu\|cuh\|c\|cpp\|h\|hpp\):\d\+' contained
syntax match computeSanitizerThread '\<\%([Tt]hread\|[Bb]lock\)\s\+([^)]*)' contained
syntax match computeSanitizerError '\<\%(Invalid\|Uninitialized\|Misaligned\|Malloc/Free error\|Leaked\|Barrier error detected\|Warpgroup MMA sequence error detected\|Program hit\|ERROR:\|Error:\).*$' contained contains=computeSanitizerNumber,computeSanitizerAddress,computeSanitizerLocation,computeSanitizerThread
syntax match computeSanitizerWarning '\<\%(WARNING\|Warning\):.*$' contained contains=computeSanitizerNumber,computeSanitizerAddress,computeSanitizerLocation
syntax match computeSanitizerSummary '\<\%(ERROR\|RACECHECK\|LEAK\) SUMMARY:.*$' contained contains=computeSanitizerNumber
syntax match computeSanitizerSuccess '\<ERROR SUMMARY: 0 errors\>' contained
highlight default link computeSanitizerPrefix Comment
highlight default link computeSanitizerHeader Title
highlight default link computeSanitizerNumber Number
highlight default link computeSanitizerAddress Constant
highlight default link computeSanitizerLocation Directory
highlight default link computeSanitizerThread Identifier
highlight default link computeSanitizerError ErrorMsg
highlight default link computeSanitizerWarning WarningMsg
highlight default link computeSanitizerSummary Statement
highlight default link computeSanitizerSuccess MoreMsg

let b:current_syntax = "computesanitizer"
