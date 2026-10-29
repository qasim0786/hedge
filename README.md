# Hedge

Hedge is a free Mac app from [Technospike](https://techno-spike.com/). It measures caches, logs, and developer leftovers, then moves what you select into the Trash. It also shows memory, temperature, and a few security switches.

Hedge does not upload a scan, and it does not collect an account.

## Install

You need a Mac on macOS 14 or later.

**One command.** This downloads Hedge and puts it in Applications:

```bash
curl -fsSL https://raw.githubusercontent.com/qasim0786/hedge/main/install.sh | bash
```

**Disk image.** Download [Hedge.dmg](https://github.com/qasim0786/hedge/releases/latest) from Releases, open it, and drag Hedge onto Applications.

The first time Hedge opens, click **Choose Home Folder** and select the folder named for your account (the one that contains Desktop, Documents, and Library). macOS asks because Hedge is sandboxed. Nothing is deleted during that step.

macOS may say the developer cannot be verified. Right-click `Hedge.app`, choose **Open**, then **Open** again.

To build the disk image yourself, run `scripts/make-dmg.sh`. That needs Xcode. Opening `Hedge.xcodeproj` and pressing Run still works if you want to stay in Xcode.

## Use

The sidebar is the whole app.

**Overview.** Hedge measures caches, browser caches, developer tools, Xcode leftovers, logs, old installers in Downloads, and the Trash. Checked items are included. **Trim** moves them to the Trash, where you can put them back. Emptying the Trash is the only permanent delete, and Hedge asks first. Documents, photos, mail, and passwords are outside the scan. A scan deletes nothing.

**Health.** Processor, memory, and free disk, plus the apps using the most memory.

**Memory.** A split of app, wired, compressed, cached, and free memory. Cached memory is already available to macOS. Select apps and choose **Quit**. Hedge asks them to close. They can still show a save dialog. Finder, the Dock, and Hedge stay off the list. **Activity Monitor** is there if macOS will not let Hedge quit an app.

**Temperature.** Cool, Warm, Hot, or Throttling. That is the thermal state macOS reports, with a live processor trace.

**Security.** A read of FileVault, the firewall, Gatekeeper, System Integrity Protection, the wake password, automatic login, the guest account, remote login, update checks, and XProtect. Hedge does not change these, and it does not scan files for malware. **Settings** opens the matching System Settings pane when macOS can show one.

**Activity.** A short local record of trims and quit requests.

## Donate

Hedge is free. A gift is optional. It goes to Qasim Malik.

Send Pakistani rupees to one of these personal accounts. Copy the account title exactly as it is written. [Wise](https://wise.com/) and similar services need the title and the IBAN. A bank wire also needs the SWIFT code. The same details are on [Donate to Qasim Malik](https://techno-spike.com/donate-to-qasim-malik/).

**National Bank of Pakistan**

| | |
| --- | --- |
| Account title | Muhammad qasim Malik |
| IBAN | PK32NBPA0505003166863228 |
| SWIFT | NBPAPKKA |

**United Bank Limited**

| | |
| --- | --- |
| Account title | Muhammad QASIM MALIK |
| IBAN | PK54UNIL0109000291588122 |
| SWIFT | UNILPKKA |

**JS Bank (Zindagi)**

| | |
| --- | --- |
| Account title | Muhammad Qasim Malik |
| IBAN | PK69JSBL9999903145098262 |
| SWIFT | JSBLPKKA |

Inside the app, **Donate** in the sidebar, or **Support > Donate**, shows these accounts. You can also write to qasim@techno-spike.com.

Guides for Hedge will live on [techno-spike.com](https://techno-spike.com/) and on Technospike’s YouTube channel, so people can find the app and see it in use.

## What a trim will not touch

Hedge refuses paths outside its allowlist. It will not delete your home folder, documents, photos, mail, passwords, or system files. Items other than Trash go to the Trash. Review the list before you trim.
