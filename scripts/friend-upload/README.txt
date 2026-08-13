HOW TO UPLOAD YOUR FILES TO CLOUDFLARE
=======================================

1) Install Node.js (free):  https://nodejs.org/  -> download the LTS version and install.

2) Open the file  config.json  with a text editor (right-click -> Open with -> Notepad)
   and fill in 4 things:
     - accessKeyId     : the Access Key ID your friend gave you
     - secretAccessKey : the Secret Access Key your friend gave you
     - folder          : the FULL path of the folder that contains your files
                         (example on Windows: "D:\\Cours"  -> two backslashes \\ )
       Leave "endpoint" and "bucket" as they are.

3) Save config.json and close Notepad.

4) Double-click  upload.bat

5) Wait until it says "Done. X uploaded, 0 failed." then close the window.

IMPORTANT:
- The folder path in config.json is the "root" - all files inside it (and its
  subfolders) are uploaded, keeping their folder structure.
- Files that already exist with the same name are simply overwritten.
- Keep the keys private: they allow uploading to the Cloudflare bucket.
