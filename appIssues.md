### Issue 1: Flask-Werkzeug Version Compatibility

**Problem:**
```
ImportError: cannot import name 'url_quote' from 'werkzeug.urls'
```

**Root Cause:**
Flask 2.2.2 was installed with a newer version of Werkzeug (3.1.3) that removed the `url_quote` function, causing import errors.

**Solution:**
Updated `requirements.txt` to pin compatible versions:
```
Flask==2.2.2
Werkzeug==2.2.2
```

Then reinstalled dependencies:
```bash
pip install -r requirements.txt --force-reinstall
```

### Issue 2: Port 5000 Conflict with Apple AirPlay (Probably my issue not the app's)

**Problem:**
- Application was configured to run on port 5000
- Port 5000 was occupied by Apple's AirPlay service (ControlCenter)
- HTTP requests returned 403 Forbidden with AirTunes server response

**Root Cause:**
macOS uses port 5000 for AirPlay receiver functionality by default.

**Solution:**
Modified the application to run on port 8000 instead:
