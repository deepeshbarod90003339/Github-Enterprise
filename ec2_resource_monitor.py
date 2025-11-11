import psutil
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Configuration
MEMORY_THRESHOLD = 80  # in percent
DISK_THRESHOLD = 80    # in percent
SMTP_SERVER = 'smtp.example.com'  # Replace with actual SMTP server
SMTP_PORT = 587
EMAIL_USER = 'your_email@example.com'  # Replace with sender email
EMAIL_PASS = 'your_password'  # Replace with sender email password
EMAIL_TO = ['recipient1@example.com', 'recipient2@example.com']  # Replace with recipient emails

# Function to check memory usage
def check_memory():
    memory = psutil.virtual_memory()
    return memory.percent

# Function to check disk usage
def check_disk():
    disk = psutil.disk_usage('/')
    return disk.percent

# Function to send alert email
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

# Main monitoring logic
def monitor_resources():
    memory_usage = check_memory()
    disk_usage = check_disk()

    if memory_usage > MEMORY_THRESHOLD or disk_usage > DISK_THRESHOLD:
        subject = "EC2 Resource Usage Alert"
        body = (f"Memory Usage: {memory_usage}%\n"
                f"Disk Usage: {disk_usage}%\n"
                f"Threshold: 80%\n"
                "Please take necessary action.")
        send_email(subject, body)
    else:
        print("Resource usage is within limits.")

# Run the monitor
monitor_resources()
