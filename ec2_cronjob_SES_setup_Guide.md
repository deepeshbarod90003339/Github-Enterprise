
# EC2 Cron Job with Email Alerts Using AWS SES
This guide walks through the complete setup of a Python-based cron job on an EC2 instance using system Python, with email alerts configured via AWS Simple Email Service (SES).

## 1. Prepare the EC2 Instance

### python and pip installation on root
```bash
# Update packages:
sudo apt update && sudo apt upgrade

# Ensure Python and pip are installed:
python3 --version
pip3 --version

# Install psutil:
pip3 install --break-system-packages psutil
```

## 2. Create the Python Monitoring Script
```bash
# Create the script file:
nano ~/resource_monitor.py
```

### Python and PIP installation in virtual env
```bash
sudo apt install python3-venv
python3 -m venv ~/monitoring-env
source ~/monitoring-env/bin/activate
pip install psutil
```


#### Paste the following script:
```py
import psutil
  import smtplib
  from email.mime.text import MIMEText
  from email.mime.multipart import MIMEMultipart
  from datetime import datetime

  # Configuration
  MEMORY_THRESHOLD = 80
  DISK_THRESHOLD = 80
  SMTP_SERVER = 'email-smtp.<region>.amazonaws.com'
  SMTP_PORT = 587
  EMAIL_USER = 'SMTP_USERNAME'
  EMAIL_PASS = 'SMTP_PASSWORD'
  EMAIL_TO = ['recipient@example.com']

  def check_memory():
      return psutil.virtual_memory().percent

  def check_disk():
      return psutil.disk_usage('/').percent

  def send_email(subject, body):
      msg = MIMEMultipart()
      msg['From'] = EMAIL_USER
      msg['To'] = ", ".join(EMAIL_TO)
      msg['Subject'] = subject
      msg.attach(MIMEText(body, 'plain'))

      try:
          server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
          server.starttls()
          server.login(EMAIL_USER, EMAIL_PASS)
          server.sendmail(EMAIL_USER, EMAIL_TO, msg.as_string())
          server.quit()
          print("Alert email sent successfully.")
      except Exception as e:
          print(f"Failed to send email: {e}")

  def monitor_resources():
      memory_usage = check_memory()
      disk_usage = check_disk()

      with open("/home/ubuntu/resource_monitor.log", "a") as log:
          log.write(f"Script ran at: {datetime.now()}\n")

      if memory_usage > MEMORY_THRESHOLD or disk_usage > DISK_THRESHOLD:
          subject = "EC2 Resource Usage Alert"
          body = (f"Memory Usage: {memory_usage}%\n"
                  f"Disk Usage: {disk_usage}%\n"
                  f"Threshold: 80%\n"
                  "Please take necessary action.")
          send_email(subject, body)
      else:
          with open("/home/ubuntu/resource_monitor.log", "a") as log:
              log.write("Resource usage is within limits.\n")

  monitor_resources()

# Save and exit.
```

## 3. Test the Script
```bash 
# Run manually:
python3 ~/resource_monitor.py

# Check the log:
cat ~/resource_monitor.log
```

## 4. Set Up the Cron Job
```bash
# Open crontab:
crontab -e

# Add this line:
*/15 * * * * /usr/bin/python3 /home/ubuntu/resource_monitor.py >> /home/ubuntu/resource_monitor.log 2>&1

# Save and exit.

# for Verfication:
cat /home/ubuntu/resource_monitor.log
```

## 5. Configure AWS SES for SMTP

##### a. Access Amazon SES

- Go to AWS Console > SES (Simple Email Service)

##### b. Verify Email or Domain

- Navigate to Verified Identities
- Click Create Identity
- Choose Email Address or Domain
- Complete the verification process

##### c. Create SMTP Credentials

- In SES > SMTP Settings > Click Create SMTP Credentials
- Follow prompts to create IAM user with SES access
- Save the SMTP 'username' and 'password'

##### d. Note SMTP Endpoint

- Example: email-smtp.us-east-1.amazonaws.com
- Use port 587 for TLS

##### e. Update Python Script with SMTP Details
Replace placeholders in the script:
SMTP_SERVER = 'email-smtp.us-east-1.amazonaws.com'
SMTP_PORT = 587
EMAIL_USER = `your_smtp_username`
EMAIL_PASS = `your_smtp_password`
EMAIL_TO = ['your_verified_email@example.com']

✅ Done!
Your EC2 instance now runs a cron job every 15 minutes to monitor system resources and sends email alerts via AWS SES if thresholds are breached.
