-- ============================================================
-- CS232: Email-based Remote Server Monitoring System
-- Complete SQL Script: DDL + Sample Data + Queries + Triggers
-- ============================================================


-- ============================================================
-- SECTION 1: CREATE TABLES (DDL)
-- ============================================================

-- Drop tables in reverse dependency order (if re-running)
DROP TABLE IF EXISTS Email_Log CASCADE;
DROP TABLE IF EXISTS Alert_Events CASCADE;
DROP TABLE IF EXISTS Alert_Rules CASCADE;
DROP TABLE IF EXISTS Metrics CASCADE;
DROP TABLE IF EXISTS Server_Personnel CASCADE;
DROP TABLE IF EXISTS Personnel CASCADE;
DROP TABLE IF EXISTS Servers CASCADE;


-- 1. Servers
CREATE TABLE Servers (
    server_id     VARCHAR(10)  PRIMARY KEY,
    hostname      VARCHAR(100) NOT NULL UNIQUE,
    ip_address    VARCHAR(45)  NOT NULL UNIQUE,
    environment   VARCHAR(20)  NOT NULL CHECK (environment IN ('production', 'staging', 'development')),
    status        VARCHAR(10)  NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    registered_at TIMESTAMP    NOT NULL DEFAULT NOW()
);


-- 2. Personnel
CREATE TABLE Personnel (
    person_id VARCHAR(10)  PRIMARY KEY,
    name      VARCHAR(100) NOT NULL,
    email     VARCHAR(150) NOT NULL UNIQUE,
    role      VARCHAR(20)  NOT NULL CHECK (role IN ('admin', 'viewer')),
    created_at TIMESTAMP   NOT NULL DEFAULT NOW()
);


-- 3. Server_Personnel (many-to-many: which admin receives alerts for which server)
CREATE TABLE Server_Personnel (
    server_id VARCHAR(10) NOT NULL REFERENCES Servers(server_id) ON DELETE CASCADE,
    person_id VARCHAR(10) NOT NULL REFERENCES Personnel(person_id) ON DELETE CASCADE,
    PRIMARY KEY (server_id, person_id)
);


-- 4. Metrics
CREATE TABLE Metrics (
    metric_id   VARCHAR(10)    PRIMARY KEY,
    server_id   VARCHAR(10)    NOT NULL REFERENCES Servers(server_id) ON DELETE CASCADE,
    metric_type VARCHAR(30)    NOT NULL CHECK (metric_type IN ('cpu_usage', 'memory_usage', 'disk_usage', 'network_usage')),
    value       NUMERIC(6, 2)  NOT NULL CHECK (value >= 0),
    unit        VARCHAR(20)    NOT NULL DEFAULT 'percent',
    recorded_at TIMESTAMP      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_metrics_server_id  ON Metrics(server_id);
CREATE INDEX idx_metrics_recorded_at ON Metrics(recorded_at);
CREATE INDEX idx_metrics_type       ON Metrics(metric_type);


-- 5. Alert_Rules
CREATE TABLE Alert_Rules (
    rule_id     VARCHAR(10)   PRIMARY KEY,
    server_id   VARCHAR(10)   NOT NULL REFERENCES Servers(server_id) ON DELETE CASCADE,
    metric_type VARCHAR(30)   NOT NULL CHECK (metric_type IN ('cpu_usage', 'memory_usage', 'disk_usage', 'network_usage')),
    threshold   NUMERIC(6, 2) NOT NULL CHECK (threshold > 0 AND threshold <= 100),
    severity    VARCHAR(10)   NOT NULL CHECK (severity IN ('warning', 'critical')),
    status      VARCHAR(10)   NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    cooldown_minutes INT      NOT NULL DEFAULT 10,
    created_at  TIMESTAMP     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_alertrules_server_id ON Alert_Rules(server_id);


-- 6. Alert_Events
CREATE TABLE Alert_Events (
    event_id      VARCHAR(50)   PRIMARY KEY,
    rule_id       VARCHAR(10)   NOT NULL REFERENCES Alert_Rules(rule_id) ON DELETE CASCADE,
    metric_id     VARCHAR(10)   NOT NULL REFERENCES Metrics(metric_id) ON DELETE CASCADE,
    severity      VARCHAR(10)   NOT NULL CHECK (severity IN ('warning', 'critical')),
    metric_value  NUMERIC(6, 2) NOT NULL,
    triggered_at  TIMESTAMP     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_alertevents_rule_id    ON Alert_Events(rule_id);
CREATE INDEX idx_alertevents_triggered  ON Alert_Events(triggered_at);
CREATE INDEX idx_alertevents_severity   ON Alert_Events(severity);


-- 7. Email_Log
CREATE TABLE Email_Log (
    log_id           VARCHAR(50) PRIMARY KEY,
    event_id         VARCHAR(50) NOT NULL REFERENCES Alert_Events(event_id) ON DELETE CASCADE,
    person_id        VARCHAR(10) NOT NULL REFERENCES Personnel(person_id) ON DELETE CASCADE,
    recipient_email  VARCHAR(150) NOT NULL,
    sent_at          TIMESTAMP   NOT NULL DEFAULT NOW(),
    status           VARCHAR(10) NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'failed', 'pending'))
);

CREATE INDEX idx_emaillog_event_id ON Email_Log(event_id);
CREATE INDEX idx_emaillog_sent_at  ON Email_Log(sent_at);


-- ============================================================
-- SECTION 2: SAMPLE DATA (INSERT STATEMENTS)
-- ============================================================

-- Servers
INSERT INTO Servers (server_id, hostname, ip_address, environment, status) VALUES
('SRV001', 'web-prod-01',    '192.168.1.10', 'production',  'active'),
('SRV002', 'db-staging-02',  '192.168.1.22', 'staging',     'active'),
('SRV003', 'mail-dev-03',    '10.0.0.5',     'development', 'inactive');


-- Personnel
INSERT INTO Personnel (person_id, name, email, role) VALUES
('P001', 'Ali Hassan',   'ali.hassan@giki.edu.pk',   'admin'),
('P002', 'Sara Malik',   'sara.malik@giki.edu.pk',   'viewer'),
('P003', 'Omar Farooq',  'omar.farooq@giki.edu.pk',  'admin');


-- Server-Personnel assignments
INSERT INTO Server_Personnel (server_id, person_id) VALUES
('SRV001', 'P001'),
('SRV001', 'P003'),
('SRV002', 'P001'),
('SRV003', 'P003');


-- Alert Rules
INSERT INTO Alert_Rules (rule_id, server_id, metric_type, threshold, severity, status, cooldown_minutes) VALUES
('AR001', 'SRV001', 'cpu_usage',    85.00, 'critical', 'active', 10),
('AR002', 'SRV002', 'memory_usage', 90.00, 'warning',  'active', 15),
('AR003', 'SRV001', 'disk_usage',   75.00, 'warning',  'active', 10);


-- Metrics
INSERT INTO Metrics (metric_id, server_id, metric_type, value, unit, recorded_at) VALUES
('M001', 'SRV001', 'cpu_usage',    0, 'percent', '2025-04-01 08:00:00'),
('M002', 'SRV001', 'memory_usage', 76.20, 'percent', '2025-04-01 08:00:00'),
('M003', 'SRV002', 'disk_usage',   82.00, 'percent', '2025-04-01 08:05:00'),
('M004', 'SRV002', 'memory_usage', 93.80, 'percent', '2025-04-01 08:05:00'),
('M005', 'SRV003', 'cpu_usage',    45.30, 'percent', '2025-04-01 08:10:00');


-- Alert Events
INSERT INTO Alert_Events (event_id, rule_id, metric_id, severity, metric_value, triggered_at) VALUES
('AE001', 'AR001', 'M001', 'critical', 91.50, '2025-04-01 08:00:00'),
('AE002', 'AR002', 'M004', 'warning',  93.80, '2025-04-01 08:05:00'),
('AE003', 'AR003', 'M003', 'warning',  82.00, '2025-04-01 08:05:00');


-- Email Log
INSERT INTO Email_Log (log_id, event_id, person_id, recipient_email, sent_at, status) VALUES
('EL001', 'AE001', 'P001', 'ali.hassan@giki.edu.pk',  '2025-04-01 08:01:00', 'sent'),
('EL002', 'AE002', 'P001', 'ali.hassan@giki.edu.pk',  '2025-04-01 08:06:00', 'sent'),
('EL003', 'AE003', 'P003', 'omar.farooq@giki.edu.pk', '2025-04-01 08:06:00', 'sent');


-- ============================================================
-- SECTION 3: CORE SQL QUERIES
-- ============================================================

-- Q1: Latest metric reading per server
SELECT s.hostname, m.metric_type, m.value, m.unit, m.recorded_at
FROM Metrics m
JOIN Servers s ON m.server_id = s.server_id
WHERE m.recorded_at = (
    SELECT MAX(m2.recorded_at)
    FROM Metrics m2
    WHERE m2.server_id = m.server_id AND m2.metric_type = m.metric_type
)
ORDER BY s.hostname, m.metric_type;

-- Q2: All active alert rules with server details
SELECT s.hostname, ar.metric_type, ar.threshold, ar.severity, ar.cooldown_minutes
FROM Alert_Rules ar
JOIN Servers s ON ar.server_id = s.server_id
WHERE ar.status = 'active'
ORDER BY ar.severity DESC, s.hostname;


-- Q3: All triggered alert events with server and rule info
SELECT ae.event_id, s.hostname, ar.metric_type, ae.severity,
       ae.metric_value, ar.threshold, ae.triggered_at
FROM Alert_Events ae
JOIN Alert_Rules ar ON ae.rule_id = ar.rule_id
JOIN Servers s      ON ar.server_id = s.server_id
ORDER BY ae.triggered_at DESC;


-- Q4: Average CPU usage per server in the last 24 hours
SELECT s.hostname,
       ROUND(AVG(m.value), 2) AS avg_cpu_percent,
       MAX(m.value)           AS peak_cpu_percent,
       COUNT(*)               AS readings
FROM Metrics m
JOIN Servers s ON m.server_id = s.server_id
WHERE m.metric_type = 'cpu_usage'
  AND m.recorded_at >= NOW() - INTERVAL '24 hours'
GROUP BY s.hostname
ORDER BY avg_cpu_percent DESC;


-- Q5: Alert frequency per server (total events grouped by severity)
SELECT s.hostname, ae.severity, COUNT(*) AS total_alerts
FROM Alert_Events ae
JOIN Alert_Rules ar ON ae.rule_id = ar.rule_id
JOIN Servers s      ON ar.server_id = s.server_id
GROUP BY s.hostname, ae.severity
ORDER BY s.hostname, ae.severity;


-- Q6: Top-5 highest metric readings ever recorded
SELECT s.hostname, m.metric_type, m.value, m.recorded_at
FROM Metrics m
JOIN Servers s ON m.server_id = s.server_id
ORDER BY m.value DESC
LIMIT 5;


-- Q7: Email dispatch history with alert details
SELECT el.log_id, s.hostname, ar.metric_type, ae.severity,
       p.name AS recipient_name, el.recipient_email, el.sent_at, el.status
FROM Email_Log el
JOIN Alert_Events ae ON el.event_id = ae.event_id
JOIN Alert_Rules ar  ON ae.rule_id  = ar.rule_id
JOIN Servers s       ON ar.server_id = s.server_id
JOIN Personnel p     ON el.person_id = p.person_id
ORDER BY el.sent_at DESC;


-- Q8: Servers with no alerts in the past 7 days (healthy servers)
SELECT s.server_id, s.hostname, s.environment
FROM Servers s
WHERE s.server_id NOT IN (
    SELECT ar.server_id
    FROM Alert_Events ae
    JOIN Alert_Rules ar ON ae.rule_id = ar.rule_id
    WHERE ae.triggered_at >= NOW() - INTERVAL '7 days'
)
ORDER BY s.hostname;


-- Q9: Admins and the servers they are responsible for
SELECT p.name, p.email, p.role, s.hostname, s.environment
FROM Personnel p
JOIN Server_Personnel sp ON p.person_id = sp.person_id
JOIN Servers s           ON sp.server_id = s.server_id
ORDER BY p.name;


-- Q10: Metric trend report (hourly averages for a specific server)
SELECT DATE_TRUNC('hour', m.recorded_at) AS hour_bucket,
       m.metric_type,
       ROUND(AVG(m.value), 2) AS avg_value
FROM Metrics m
WHERE m.server_id = 'SRV001'
GROUP BY hour_bucket, m.metric_type
ORDER BY hour_bucket, m.metric_type;


-- ============================================================
-- SECTION 4: VIEWS
-- ============================================================

-- View: Server health summary (latest reading per metric per server)
CREATE OR REPLACE VIEW vw_server_health AS
SELECT DISTINCT ON (m.server_id, m.metric_type)
    s.hostname,
    s.environment,
    s.status,
    m.metric_type,
    m.value,
    m.recorded_at
FROM Metrics m
JOIN Servers s ON m.server_id = s.server_id
ORDER BY m.server_id, m.metric_type, m.recorded_at DESC;


-- View: Admin-only dashboard (only admins see all events)
CREATE OR REPLACE VIEW vw_admin_alert_dashboard AS
SELECT ae.event_id, s.hostname, ar.metric_type, ae.severity,
       ae.metric_value, ae.triggered_at,
       p.name AS notified_person, el.status AS email_status
FROM Alert_Events ae
JOIN Alert_Rules ar  ON ae.rule_id  = ar.rule_id
JOIN Servers s       ON ar.server_id = s.server_id
LEFT JOIN Email_Log el ON ae.event_id = el.event_id
LEFT JOIN Personnel p  ON el.person_id = p.person_id
WHERE p.role = 'admin'
ORDER BY ae.triggered_at DESC;


-- ============================================================
-- SECTION 5: STORED PROCEDURES
-- ============================================================

-- Procedure: Insert a metric reading (bulk-safe)
CREATE OR REPLACE PROCEDURE insert_metric(
    p_metric_id   VARCHAR,
    p_server_id   VARCHAR,
    p_metric_type VARCHAR,
    p_value       NUMERIC,
    p_unit        VARCHAR DEFAULT 'percent'
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO Metrics (metric_id, server_id, metric_type, value, unit, recorded_at)
    VALUES (p_metric_id, p_server_id, p_metric_type, p_value, p_unit, NOW());
END;
$$;


-- Procedure: Dispatch alert email with deduplication (cooldown check)
-- Called manually or from application layer after a trigger fires.
CREATE OR REPLACE PROCEDURE dispatch_alert_email(
    p_event_id   VARCHAR,
    p_person_id  VARCHAR,
    p_email      VARCHAR,
    p_rule_id    VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    v_cooldown     INT;
    v_last_sent    TIMESTAMP;
    v_new_log_id   VARCHAR;
BEGIN
    -- Get cooldown window for the rule
    SELECT cooldown_minutes INTO v_cooldown
    FROM Alert_Rules WHERE rule_id = p_rule_id;

    -- Find the last email sent to this person for any event from the same rule
    SELECT MAX(el.sent_at) INTO v_last_sent
    FROM Email_Log el
    JOIN Alert_Events ae ON el.event_id = ae.event_id
    WHERE ae.rule_id = p_rule_id
      AND el.person_id = p_person_id;

    -- Only dispatch if outside the cooldown window
    IF v_last_sent IS NULL OR v_last_sent < NOW() - (v_cooldown || ' minutes')::INTERVAL THEN
        v_new_log_id := 'EL_' || CAST(EXTRACT(EPOCH FROM NOW()) AS BIGINT)::TEXT;
        INSERT INTO Email_Log (log_id, event_id, person_id, recipient_email, sent_at, status)
        VALUES (v_new_log_id, p_event_id, p_person_id, p_email, NOW(), 'sent');
        RAISE NOTICE 'Email dispatched to % for event %', p_email, p_event_id;
    ELSE
        RAISE NOTICE 'Cooldown active — email suppressed for % (last sent: %)', p_email, v_last_sent;
    END IF;
END;
$$;


-- ============================================================
-- SECTION 6: TRIGGERS
-- ============================================================

-- Trigger function: Evaluate alert rules after a new metric is inserted
CREATE OR REPLACE FUNCTION fn_evaluate_alert_rules()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_rule         RECORD;
    v_event_id     VARCHAR;
    v_last_event   TIMESTAMP;
BEGIN
    -- Loop over all active rules matching this server + metric type
    FOR v_rule IN
        SELECT * FROM Alert_Rules
        WHERE server_id   = NEW.server_id
          AND metric_type = NEW.metric_type
          AND status      = 'active'
          AND threshold   <= NEW.value
    LOOP
        -- Check cooldown: suppress if an event was already fired recently
        SELECT MAX(triggered_at) INTO v_last_event
        FROM Alert_Events
        WHERE rule_id = v_rule.rule_id;

        IF v_last_event IS NULL OR
           v_last_event < NOW() - (v_rule.cooldown_minutes || ' minutes')::INTERVAL
        THEN
            -- Generate a simple unique event ID
            v_event_id := 'AE_' || NEW.metric_id || '_' || v_rule.rule_id;

            -- Insert into Alert_Events (atomic with the metric insert)
            INSERT INTO Alert_Events (event_id, rule_id, metric_id, severity, metric_value, triggered_at)
            VALUES (v_event_id, v_rule.rule_id, NEW.metric_id, v_rule.severity, NEW.value, NOW());

            RAISE NOTICE 'ALERT: % breach on % — value=%, threshold=%, severity=%',
                NEW.metric_type, NEW.server_id, NEW.value, v_rule.threshold, v_rule.severity;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

-- Attach trigger to Metrics table
CREATE TRIGGER trg_after_metric_insert
AFTER INSERT ON Metrics
FOR EACH ROW
EXECUTE FUNCTION fn_evaluate_alert_rules();


-- ============================================================
-- SECTION 7: TEST THE TRIGGER
-- ============================================================

-- This insert should fire the trigger and create an Alert_Event
-- because SRV001 has a rule: cpu_usage > 85 = critical
INSERT INTO Metrics (metric_id, server_id, metric_type, value, unit)
VALUES ('M006', 'SRV001', 'cpu_usage', 95.00, 'percent');

-- Verify that a new alert event was created
SELECT * FROM Alert_Events ORDER BY triggered_at DESC LIMIT 5;

-- Verify server health view
SELECT * FROM vw_server_health;

-- Verify admin dashboard view
SELECT * FROM vw_admin_alert_dashboard;



CREATE OR REPLACE FUNCTION fn_evaluate_alert_rules()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_rule         RECORD;
    v_event_id     VARCHAR(50);
    v_last_event   TIMESTAMP;
    v_counter      INT;
BEGIN
    FOR v_rule IN
        SELECT * FROM Alert_Rules
        WHERE server_id   = NEW.server_id
          AND metric_type = NEW.metric_type
          AND status      = 'active'
          AND threshold   <= NEW.value
    LOOP
        SELECT MAX(triggered_at) INTO v_last_event
        FROM Alert_Events
        WHERE rule_id = v_rule.rule_id;

        IF v_last_event IS NULL OR
           v_last_event < NOW() - (v_rule.cooldown_minutes || ' minutes')::INTERVAL
        THEN
            SELECT COUNT(*) + 1 INTO v_counter FROM Alert_Events;
            v_event_id := 'AE' || LPAD(v_counter::TEXT, 6, '0');

            INSERT INTO Alert_Events (event_id, rule_id, metric_id, severity, metric_value, triggered_at)
            VALUES (v_event_id, v_rule.rule_id, NEW.metric_id, v_rule.severity, NEW.value, NOW());

            RAISE NOTICE 'ALERT fired: % on % value=% severity=%',
                NEW.metric_type, NEW.server_id, NEW.value, v_rule.severity;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

SELECT table_name, column_name, character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public'
  AND data_type = 'character varying'
ORDER BY table_name, column_name;

ALTER TABLE Metrics ALTER COLUMN metric_id TYPE VARCHAR(50);


ALTER TABLE Metrics ALTER COLUMN metric_id TYPE VARCHAR(50);
ALTER TABLE Alert_Events ALTER COLUMN metric_id TYPE VARCHAR(50);


SELECT * FROM Alert_Events ORDER BY triggered_at DESC LIMIT 5;


SELECT * FROM Email_Log ORDER BY sent_at DESC LIMIT 5;

DELETE FROM Email_Log;


select* from Email_log;


INSERT INTO Personnel (person_id, name, email, role)
VALUES ('P004', 'Taj Momin', 'tajmomin90@gmail.com', 'admin');


INSERT INTO Server_Personnel (server_id, person_id) VALUES ('SRV001', 'P004');
INSERT INTO Server_Personnel (server_id, person_id) VALUES ('SRV002', 'P004');
INSERT INTO Server_Personnel (server_id, person_id) VALUES ('SRV003', 'P004');

INSERT INTO Metrics (metric_id, server_id, metric_type, value, unit)
VALUES ('M007', 'SRV001', 'cpu_usage', 92.00, 'percent');