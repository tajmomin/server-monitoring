const express = require('express');
const cors    = require('cors');
const path    = require('path');
require('dotenv').config();

const pool               = require('./db');
const { sendAlertEmail } = require('./mailer');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));


// ─────────────────────────────────────────────
// Dispatch emails for any new alert events
// ─────────────────────────────────────────────
async function dispatchPendingAlerts(metricId) {
  console.log('🔍 Checking alerts for metric:', metricId);

  const eventsRes = await pool.query(`
    SELECT ae.event_id, ae.rule_id, ae.severity, ae.metric_value,
           ar.threshold, ar.cooldown_minutes, ar.server_id, ar.metric_type,
           s.hostname
    FROM Alert_Events ae
    JOIN Alert_Rules ar ON ae.rule_id   = ar.rule_id
    JOIN Servers s      ON ar.server_id = s.server_id
    WHERE ae.metric_id = $1
      AND ae.event_id NOT IN (SELECT event_id FROM Email_Log)
  `, [metricId]);

  console.log('📋 Alert events found:', eventsRes.rows.length);

  for (const event of eventsRes.rows) {
    console.log('🚨 Processing event:', event.event_id, '| server:', event.server_id, '| hostname:', event.hostname);

    const adminsRes = await pool.query(`
      SELECT p.person_id, p.email, p.name
      FROM Personnel p
      JOIN Server_Personnel sp ON p.person_id = sp.person_id
      WHERE sp.server_id = $1 AND p.role = 'admin'
    `, [event.server_id]);

    console.log('👥 Admins found:', adminsRes.rows.length, adminsRes.rows.map(a => a.email));

    for (const admin of adminsRes.rows) {
      console.log('📧 Attempting to send email to:', admin.email);

      const sent = await sendAlertEmail(
        admin.email,
        event.hostname,
        event.metric_type,
        event.metric_value,
        event.threshold,
        event.severity
      );

      console.log('📬 Email result for', admin.email, ':', sent);

      const logId = `EL_${Date.now()}_${admin.person_id}`;
      await pool.query(`
        INSERT INTO Email_Log (log_id, event_id, person_id, recipient_email, sent_at, status)
        VALUES ($1, $2, $3, $4, NOW(), $5)
      `, [logId, event.event_id, admin.person_id, admin.email, sent ? 'sent' : 'failed']);

      console.log('💾 Email log saved:', logId);
    }
  }
}


// ─────────────────────────────────────────────
// ROUTES
// ─────────────────────────────────────────────

// POST /api/metrics — insert a new metric reading
app.post('/api/metrics', async (req, res) => {
  const { metric_id, server_id, metric_type, value, unit } = req.body;

  console.log('📥 Incoming metric:', req.body);

  if (!metric_id || !server_id || !metric_type || value === undefined) {
    return res.status(400).json({ error: 'metric_id, server_id, metric_type, and value are required' });
  }

  try {
    await pool.query(`
      INSERT INTO Metrics (metric_id, server_id, metric_type, value, unit, recorded_at)
      VALUES ($1, $2, $3, $4, $5, NOW())
    `, [metric_id, server_id, metric_type, value, unit || 'percent']);

    console.log('✅ Metric inserted:', metric_id);

    await dispatchPendingAlerts(metric_id);

    res.status(201).json({ message: 'Metric recorded successfully' });
  } catch (err) {
    console.error('❌ Error inserting metric:', err.message);
    res.status(500).json({ error: err.message });
  }
});


// GET /api/servers — list all servers with latest metrics
app.get('/api/servers', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT s.*,
        (SELECT m.value FROM Metrics m
         WHERE m.server_id = s.server_id AND m.metric_type = 'cpu_usage'
         ORDER BY m.recorded_at DESC LIMIT 1) AS latest_cpu,
        (SELECT m.value FROM Metrics m
         WHERE m.server_id = s.server_id AND m.metric_type = 'memory_usage'
         ORDER BY m.recorded_at DESC LIMIT 1) AS latest_memory,
        (SELECT m.value FROM Metrics m
         WHERE m.server_id = s.server_id AND m.metric_type = 'disk_usage'
         ORDER BY m.recorded_at DESC LIMIT 1) AS latest_disk
      FROM Servers s
      ORDER BY s.hostname
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('❌ /api/servers error:', err.message);
    res.status(500).json({ error: err.message });
  }
});


// GET /api/metrics/:server_id — recent metrics for a server
app.get('/api/metrics/:server_id', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT * FROM Metrics
      WHERE server_id = $1
      ORDER BY recorded_at DESC
      LIMIT 50
    `, [req.params.server_id]);
    res.json(result.rows);
  } catch (err) {
    console.error('❌ /api/metrics error:', err.message);
    res.status(500).json({ error: err.message });
  }
});


// GET /api/alerts — recent alert events
app.get('/api/alerts', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT ae.event_id, ae.severity, ae.metric_value, ae.triggered_at,
             ar.metric_type, ar.threshold,
             s.hostname
      FROM Alert_Events ae
      JOIN Alert_Rules ar ON ae.rule_id   = ar.rule_id
      JOIN Servers s      ON ar.server_id = s.server_id
      ORDER BY ae.triggered_at DESC
      LIMIT 20
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('❌ /api/alerts error:', err.message);
    res.status(500).json({ error: err.message });
  }
});


// GET /api/emaillog — email dispatch history
app.get('/api/emaillog', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT el.log_id, el.recipient_email, el.sent_at, el.status,
             ae.severity, s.hostname, ar.metric_type
      FROM Email_Log el
      JOIN Alert_Events ae ON el.event_id  = ae.event_id
      JOIN Alert_Rules ar  ON ae.rule_id   = ar.rule_id
      JOIN Servers s       ON ar.server_id = s.server_id
      ORDER BY el.sent_at DESC
      LIMIT 20
    `);
    res.json(result.rows);
  } catch (err) {
    console.error('❌ /api/emaillog error:', err.message);
    res.status(500).json({ error: err.message });
  }
});


// Serve frontend
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});


app.listen(PORT, () => {
  console.log(`🚀 Server running at http://localhost:${PORT}`);
});