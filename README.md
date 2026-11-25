

#### For Radeon Pro RDNA1 (5000 series) and RDNA2 (6000 series):
1. [AMD 26.6.1](https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-26-6-1.html) (25.2.1 kernel)
2. [AMD 25.2.1](https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-25-2-1.html) (original kernel)

1. Download this repository - click green "Code" button from top of this GitHub page, then "Download ZIP", and unzip it
2. Download the official AMD driver matching your GPU (see supported [Drivers](#drivers) section above)
3. Uninstall your existing GPU driver using DDU or RAPR (see [Tools](#tools) section below)
4. Run official AMD driver installer you got in step 2. **Installation will fail** — that is expected — just close its window
5. Now from extracted Falcon package, right-click `install-driver.cmd` and "Run as admin". **In case of any issues**, start it manually:
   * click Option+R (or Win+R)
   * type `cmd` and hit Ctrl+Shift+Enter (to run as admin)
   * type `cd C:\Users\<your-username>\Downloads\project-falcon-master` and hit Enter
   * type `.\install-driver.cmd` and hit Enter
6. Script will show simple menu, where u need select an option that match your GPU and AMD driver version that you've downloaded
7. Patiently wait, sometime script hangs, just hit Enter after minute or so
8. To install AMD Software - run `C:\AMD\AMD-Software-Installer\Packages\Drivers\Display2\WT6A_INF\B...\ccc2_install.exe` (use `Display` if `Display2` doesn't work/exist)




