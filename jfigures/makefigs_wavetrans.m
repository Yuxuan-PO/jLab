function[]=makefigs_wavetrans
%MAKEFIGS_WAVETRANS  Makes a sample figure for WAVETRANS.

load bravo94
%not using 'use' as it's not compatible in scripts with some systems
num=bravo94.rcm.num;
cv=bravo94.rcm.cv;

vindex(cv,2,2);

gamma=3;beta=2;
fs=morsespace(gamma,beta,{0.05,pi},pi/1000,4);
[wp,wn]=wavetrans(cv,conj(cv),{gamma,beta,fs,'bandpass'});
h=wavespecplot(yearfrac(num),vfilt(cv,24),1./fs,sqrt(squared(wp)+squared(wn)));
colormap lansey
axes(h),ylim([-35 55]),hlines(0,'k:'),caxis([0.25 21])

%To print
if 0
    currentdir=pwd;
    cd([whichdir('jlab_license') '/figures'])
    print -dpng wavetrans
    crop wavetrans.png
    cd(currentdir)
end
