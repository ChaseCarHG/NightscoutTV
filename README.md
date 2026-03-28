NightscoutTV for Roku  
a client screensaver/app for Roku to display read-only information from a running Nightscout server  

TIP: The info below is presented alongside screenshots on the Wiki page here: https://github.com/ChaseCarHG/NightscoutTV/wiki
  
DISCLAIMERS  
NIGHTSCOUT #WeAreNotWaiting  
(!) IMPORTANT - As with Nightscout, it is important to understand that this project:  
   • is an open-source, community-based project and is not supported by any company  
   • is not officially approved or regulated for diabetes therapy and/or treatment in any way  
   You must understand that you take full responsibility for building and running this DIY system and you agree to do so at your own risk.  
(!) SAFETY
   • This project requires a working internet connection and availability of any third-party cloud services used  
   • Do not rely only on Nightscout as the only way you have of knowing your blood glucose values and trends  
   • Make sure you're ready to cope with an unexpected failure and always have alternative ways to check your blood glucose levels  
The Roku platform is neither Safety-Grade nor Medical Grade. People change the channel. For a dedicated display, consider a SugarPixel from https://customtypeone.com/products/sugarpixel  
  
PREREQUISITES  
1. Fully-operational Nightscout server setup per https://nightscout.github.io/, with:    
   a. HTTPS:// access URL.  
   b. Access token with "readable" permission.  
      • To set up an access token, navigate to your Nightscout URL, authenticate, then top-right Hamburger Icon > Admin Tools > Subjects > Add New Subject > Name "roku", Roles "READABLE" > Click Save button.  
   c. Uploader sending it at least Continuous Glucose Monitor Information (Recommended: Nighscout Foundation's XDrip+ from https://github.com/nightscoutfoundation/xdrip)   
   d. (Optional) Other uploaders contributing information, e.g. jwoglom-tconnectsync from https://github.com/jwoglom/tconnectsync  
  
INSTALLATION  
1. Download all files -- recommend the "Releases" section on the right. Download the "NightscoutTV.zip" file (NOT the source code zip). 
   a. (Optional, recommended for developers) To ease on-TV setup, consider editing NightscoutSetup.brs at the two lines labeled "'CUSTOMIZE STRING BELOW TO EASE ROKU OSK INPUTS".  
      Afterwards, ensure all files re-zipped. (7-Zip works fine with Compression Level 9-Ultra.)
      Just ensure the .Zip archive root folder contains the 1 file ("manifest") and the 3 directories ("components", "images", & "source")).
2. To sideload-install the Zip file, refer to https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md  
   a. NOTE: Roku platform limitations prevent sideload-installed apps from providing user access to the Screensaver Settings menu option.  
            However, the Screensaver Settings menu option DOES display upon initial app sideloading.  
            Therefore, to return to Screensaver Settings, remove then re-sideload-install NightscoutTV on your Roku device.  
            This limitation will remain until the app graduates from Alpha version, when I'll publish the Beta version in the Roku App Store (free just like Nightscout).  
3. Observe the 8-second disclaimer splash screen, which says the same as the "DISCLAIMERS" section above.  
4. Configure the Setup screen IMMEDIATELY after the disclaimer splash screen disappears, due to Note 4.a. above.  
   a. NOTE: Remember the optional Step 2 can ease this process!  
  
USAGE  
1. To ensure it's now your Default Screensaver:  
   a. Go to Roku Home > Settings > Theme > Screensavers > NightscoutTV for Roku (dev) > Set as screensaver.  
      (If the option doesn't exist, then it's already set as the screensaver.)  
2. To adjust the Screensaver Start Time:  
   a. Go to Roku Home > Settings > Theme > (scroll down to "Additional settings") > Screensaver Start Time.  
3. To manually launch NightscoutTV as an app:  
   a. Go to Roku Home > (find the Black "Nightscout Owl" on a Green-Rectangle background -- sideloaded apps tend to go to bottom of the list) > Open it!  
  
TESTING THUS FAR  
• Platform: 4800X Roku Ultra boxes running Software Version 15.1, with Display Resolutions of 720p and 1080p.  
• Features: CGM, Bolus/Treatment, Temp-Basil (e.g. from Tandem tslim X2) and Profile-Basil (each displayed in a unique shade of blue), CAGE, and SAGE.   
  
PENDING INITIAL TESTING  
• IAGE  
• BAGE  
  
MORE DETAILS  
• Unfortunately, there's no Webkit or similar on Roku, so it all has to be made using Roku's available programming.  
• VALIDATE DATA RELIABILITY BEFORE MAKING DECISIONS ON IT. 
