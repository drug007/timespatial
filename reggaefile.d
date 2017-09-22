import reggae;
alias main = dubDefaultTarget!(Flags("-g -debug"));
alias ut = dubConfigurationTarget!(ExeName("ut"), Configuration("unittest"));
mixin build!(main, ut);