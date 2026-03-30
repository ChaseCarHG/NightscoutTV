# NightscoutTV for Roku   
A client screensaver/app for Roku to display read-only information from a running Nightscout server.    
(Wanna see the [Screenshots (at page bottom)](https://github.com/ChaseCarHG/NightscoutTV/blob/main/README.md#screenshots)?).  
  
---  
  
## DISCLAIMERS  
  
### NIGHTSCOUT #WeAreNotWaiting   
> **IMPORTANT** — As with Nightscout, it is important to understand that this project:  
> - is an open-source, community-based project and is not supported by any company  
> - is not officially approved or regulated for diabetes therapy and/or treatment in any way  
>  
> You must understand that you take full responsibility for building and running this DIY system and you agree to do so at your own risk.  
  
> **SAFETY**  
> - This project requires a working internet connection and availability of any third-party cloud services used  
> - Do not rely only on Nightscout as the only way you have of knowing your blood glucose values and trends  
> - Make sure you're ready to cope with an unexpected failure and always have alternative ways to check your blood glucose levels  
  
The Roku platform is neither Safety-Grade nor Medical Grade. People change the channel. For a dedicated display, consider a [SugarPixel](https://customtypeone.com/products/sugarpixel)  
  
---  
  
## PREREQUISITES   
  
1. Fully-operational [Nightscout server setup](https://nightscout.github.io/), with:  
   - **a.** HTTPS:// access URL.  
   - **b.** Access token with "readable" permission.  
     - To set up an access token, navigate to your Nightscout URL, authenticate, then top-right Hamburger Icon > Admin Tools > Subjects > Add New Subject > Name "roku", Roles "READABLE" > Click Save button.  
   - **c.** Uploader sending it at least Continuous Glucose Monitor Information  
     *(Recommended: Nightscout Foundation's [XDrip+](https://github.com/nightscoutfoundation/xdrip)*    
   - **d.** *(Optional)* Other uploaders contributing information, e.g. [jwoglom-tconnectsync](https://github.com/jwoglom/tconnectsync)  
  
---   
  
## INSTALLATION (MANUAL SIDELOADING INSTRUCTIONS)
  
* Instead of Sideloading, recommend [installing NightscoutTV from the Roku Store directly](https://github.com/ChaseCarHG/NightscoutTV/wiki#installation).
* Sideloading using the instructions below is for developers, or until Roku publishes it.   
   
1. Download all files — recommend the **Releases** section on the right. Download the `NightscoutTV.zip` file (**NOT** the source code zip).  
   - **a.** *(Optional, recommended for developers)* To ease on-TV setup, consider editing `NightscoutSetup.brs` at the two lines labeled `'CUSTOMIZE STRING BELOW TO EASE ROKU OSK INPUTS`.  
     Afterwards, ensure all files are re-zipped. *(7-Zip works fine with Compression Level 9-Ultra.)*  
     Just ensure the `.zip` archive root folder contains the 1 file (`manifest`) and the 3 directories (`components`, `images`, & `source`).  
  
2. To sideload-install the Zip file, refer to [Roku Developer's Sideloading Instructions](https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md)  
   - **a.** **NOTE:** Roku platform limitations prevent sideload-installed apps from providing user access to the Screensaver Settings menu option.  
     However, the Screensaver Settings menu option **DOES** display upon initial app sideloading.  
     Therefore, to return to Screensaver Settings, remove then re-sideload-install NightscoutTV on your Roku device.  
     This limitation will remain until the app graduates from Alpha version, when I'll publish the Beta version in the Roku App Store *(free just like Nightscout)*.  
  
3. Observe the 8-second disclaimer splash screen, which says the same as the **DISCLAIMERS** section above.  
  
4. Configure the Setup screen **IMMEDIATELY** after the disclaimer splash screen disappears, due to Note 2.a. above.  
   - **a.** **NOTE:** Remember the optional Step 1.a. can ease this process!  
  
---  
  
## USAGE  
  
1. **To ensure it's now your Default Screensaver:**  
   - Go to Roku Home > Settings > Theme > Screensavers > NightscoutTV for Roku (dev) > Set as screensaver.  
     *(If the option doesn't exist, then it's already set as the screensaver.)*   
  
2. **To adjust the Screensaver Start Time:**  
   - Go to Roku Home > Settings > Theme > *(scroll down to "Additional settings")* > Screensaver Start Time.  
   
3. **To manually launch NightscoutTV as an app:**  
   - Go to Roku Home > *(find the Black "Nightscout Owl" on a Green-Rectangle background — sideloaded apps tend to go to bottom of the list)* > Open it!  
  
---  
  
## TESTING THUS FAR  
  
| Area | Details |  
|------|---------|  
| **Platform** | 4800X Roku Ultra boxes running Software Version 15.1, with Display Resolutions of 720p and 1080p |  
| **Features** | CGM, Bolus/Treatment, Temp-Basal *(e.g. from Tandem tslim X2)* and Profile-Basal *(each displayed in a unique shade of blue)*, CAGE, and SAGE |  
   
---  
  
## HOW YOU CAN HELP  
• Check out the [Nightscout Project](https://nightscout.github.io/) and the [Nightscout Foundation](https://www.nightscoutfoundation.org/). Without their work, this project wouldn't be here.  
• Check out the [NightscoutTV Issues list](https://github.com/ChaseCarHG/NightscoutTV/issues).  
* Some items just need testing, and maybe your Nightscout server has what I don't have.  
* Some items need localization. If you're interested in NightscoutTV support in YOUR language -- let me know in the issue for it!  
* Some items warrant a developer who can handle Roku's Brightscript. There's enough already built out to learn from and scale to add those new features.  
* Unfortunately, there's no Webkit or similar on Roku, so it all has to be made using Roku's available programming.
   
AGAIN -- VALIDATE DATA RELIABILITY BEFORE MAKING DECISIONS ON IT.  
  
---  
  
## SCREENSHOTS
![002](https://github.com/user-attachments/assets/9d24fbfe-91a8-4bda-b488-a04e64137bdc)  
![NightscoutTV-Demo-24hr](https://github.com/user-attachments/assets/b0001de4-e05f-4a20-8870-d7b30ed551bf)

... or Ctrl+Click below to preview shorter timespans...  

<a href="https://github.com/user-attachments/assets/eebdfa2b-c256-4a06-bbaf-6fd63f124c97" target="_blank">
  <img src="https://github.com/user-attachments/assets/eebdfa2b-c256-4a06-bbaf-6fd63f124c97" width="19%">
</a>
<a href="https://github.com/user-attachments/assets/06d30745-d2f0-49fc-828d-795357dea753" target="_blank">
  <img src="https://github.com/user-attachments/assets/06d30745-d2f0-49fc-828d-795357dea753" width="19%">
</a>
<a href="https://github.com/user-attachments/assets/66c442c7-24f1-4360-a540-12b0ec8ce723" target="_blank">
  <img src="https://github.com/user-attachments/assets/66c442c7-24f1-4360-a540-12b0ec8ce723" width="19%">
</a>
<a href="https://github.com/user-attachments/assets/39993489-6e36-4341-9c00-ad43f10b1688" target="_blank">
  <img src="https://github.com/user-attachments/assets/39993489-6e36-4341-9c00-ad43f10b1688" width="19%">
</a>
<a href="https://github.com/user-attachments/assets/a274bc68-2e98-4eee-b93d-0e18445217f1" target="_blank">
  <img src="https://github.com/user-attachments/assets/a274bc68-2e98-4eee-b93d-0e18445217f1" width="19%">
</a>
  
  
