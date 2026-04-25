const nodemailer = require('nodemailer');
require('dotenv').config();

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

/**
 * Send an alert email to an administrator.
 * @param {string} toEmail      - Recipient email address
 * @param {string} hostname     - Server hostname that breached the threshold
 * @param {string} metricType   - e.g. cpu_usage, memory_usage
 * @param {number} metricValue  - The recorded value
 * @param {number} threshold    - The rule threshold
 * @param {string} severity     - 'warning' or 'critical'
 */
async function sendAlertEmail(toEmail, hostname, metricType, metricValue, threshold, severity) {
  const severityColor = severity === 'critical' ? '#e24b4b' : '#ef9f27';
  const severityLabel = severity.toUpperCase();

  const mailOptions = {
    from: `"Server Monitor" <${process.env.GMAIL_USER}>`,
    to: toEmail,
    subject: `[${severityLabel}] Alert: ${metricType} threshold breached on ${hostname}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: ${severityColor}; padding: 20px; border-radius: 8px 8px 0 0;">
          <h2 style="color: white; margin: 0;">⚠️ Server Alert — ${severityLabel}</h2>
        </div>
        <div style="background: #f9f9f9; padding: 24px; border: 1px solid #ddd; border-radius: 0 0 8px 8px;">
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px 0; color: #666; font-size: 14px;">Server</td>
              <td style="padding: 8px 0; font-weight: bold;">${hostname}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #666; font-size: 14px;">Metric</td>
              <td style="padding: 8px 0; font-weight: bold;">${metricType.replace('_', ' ').toUpperCase()}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #666; font-size: 14px;">Current Value</td>
              <td style="padding: 8px 0; font-weight: bold; color: ${severityColor};">${metricValue}%</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #666; font-size: 14px;">Threshold</td>
              <td style="padding: 8px 0;">${threshold}%</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #666; font-size: 14px;">Time</td>
              <td style="padding: 8px 0;">${new Date().toLocaleString()}</td>
            </tr>
          </table>
          <p style="margin-top: 20px; font-size: 13px; color: #999;">
            This alert was sent by your CS232 Server Monitoring System.
          </p>
        </div>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`📧 Alert email sent to ${toEmail}`);
    return true;
  } catch (err) {
    console.error(`❌ Failed to send email to ${toEmail}:`, err.message);
    return false;
  }
}

module.exports = { sendAlertEmail };
