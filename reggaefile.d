import reggae;
alias main = dubDefaultTarget!(CompilerFlags("-g -debug"));
alias ut = dubConfigurationTarget!(Configuration("unittest"));
mixin build!(main, ut);