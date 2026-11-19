-- 安心守护服务端初始表结构（PostgreSQL 16）
-- 约定：主键使用客户端或服务端生成的 ULID/前缀 ID（text），时间一律 timestamptz（UTC）。
-- 手机号、身份证号、执业证号只存密文（应用层 KMS 信封加密）和用于查找的 HMAC 摘要。

BEGIN;

-- 账号与家庭 ------------------------------------------------------------

CREATE TABLE users (
    id              text PRIMARY KEY,
    phone_hmac      bytea NOT NULL UNIQUE,
    phone_cipher    bytea NOT NULL,
    display_name    text NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    disabled_at     timestamptz
);

CREATE TABLE families (
    id              text PRIMARY KEY,
    name            text NOT NULL,
    created_by      text NOT NULL REFERENCES users(id),
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE family_members (
    family_id       text NOT NULL REFERENCES families(id),
    user_id         text NOT NULL REFERENCES users(id),
    role            text NOT NULL CHECK (role IN ('owner', 'admin', 'contact', 'viewer')),
    relation        text NOT NULL,
    sort_order      int  NOT NULL DEFAULT 0,
    joined_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (family_id, user_id)
);

CREATE TABLE care_recipients (
    id                  text PRIMARY KEY,
    family_id           text NOT NULL REFERENCES families(id),
    name                text NOT NULL,
    gender              text,
    birth_year          int,
    -- 家属自述，非医疗机构确认的病史
    conditions          jsonb NOT NULL DEFAULT '[]',
    current_medications jsonb NOT NULL DEFAULT '[]',
    timezone            text NOT NULL DEFAULT 'Asia/Shanghai',
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- 医生与授权 ------------------------------------------------------------

CREATE TABLE organizations (
    id              text PRIMARY KEY,
    name            text NOT NULL,
    kind            text NOT NULL CHECK (kind IN ('hospital', 'community_center', 'clinic', 'care_home')),
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE doctors (
    id                    text PRIMARY KEY,
    user_id               text NOT NULL UNIQUE REFERENCES users(id),
    organization_id       text NOT NULL REFERENCES organizations(id),
    name                  text NOT NULL,
    department            text NOT NULL,
    title                 text NOT NULL,
    license_no_cipher     bytea NOT NULL,
    -- 未通过资质审核的医生不能被绑定，也不能登录医生端
    verification_status   text NOT NULL DEFAULT 'pending'
                          CHECK (verification_status IN ('pending', 'verified', 'rejected', 'suspended')),
    verified_at           timestamptz,
    verified_by           text REFERENCES users(id),
    created_at            timestamptz NOT NULL DEFAULT now()
);

-- 照护对象 → 医生 的数据授权。报告只能发给有效授权内的医生。
CREATE TABLE doctor_authorizations (
    id                  text PRIMARY KEY,
    care_recipient_id   text NOT NULL REFERENCES care_recipients(id),
    doctor_id           text NOT NULL REFERENCES doctors(id),
    granted_by          text NOT NULL REFERENCES users(id),
    consent_id          text NOT NULL,
    granted_at          timestamptz NOT NULL DEFAULT now(),
    expires_at          timestamptz,
    revoked_at          timestamptz,
    revoked_by          text REFERENCES users(id)
);
CREATE UNIQUE INDEX doctor_authorizations_active
    ON doctor_authorizations (care_recipient_id, doctor_id)
    WHERE revoked_at IS NULL;

-- 《个人信息保护法》要求敏感个人信息单独同意，同意记录需可追溯版本。
CREATE TABLE consents (
    id                  text PRIMARY KEY,
    user_id             text NOT NULL REFERENCES users(id),
    care_recipient_id   text NOT NULL REFERENCES care_recipients(id),
    purpose             text NOT NULL,
    policy_version      text NOT NULL,
    granted_at          timestamptz NOT NULL DEFAULT now(),
    withdrawn_at        timestamptz
);
ALTER TABLE doctor_authorizations
    ADD CONSTRAINT doctor_authorizations_consent_fk FOREIGN KEY (consent_id) REFERENCES consents(id);

-- 健康数据 --------------------------------------------------------------

CREATE TABLE vital_readings (
    id                  text PRIMARY KEY,           -- App 端生成，重试同步时幂等
    care_recipient_id   text NOT NULL REFERENCES care_recipients(id),
    kind                text NOT NULL CHECK (kind IN ('bloodPressure', 'heartRate', 'bloodSugar')),
    measured_at         timestamptz NOT NULL,
    source              text NOT NULL CHECK (source IN ('voice', 'typed', 'tap', 'device')),
    recorded_by         text NOT NULL,
    systolic            smallint,
    diastolic           smallint,
    heart_rate          smallint,
    blood_sugar         numeric(4, 1),
    transcript          text,
    deleted_at          timestamptz,                -- 撤销记录只做软删除，已生成的报告不受影响
    received_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX vital_readings_recipient_time ON vital_readings (care_recipient_id, measured_at);

CREATE TABLE medication_plans (
    id                  text PRIMARY KEY,
    care_recipient_id   text NOT NULL REFERENCES care_recipients(id),
    name                text NOT NULL,
    dosage              text NOT NULL,
    compartment         text,
    schedule            jsonb NOT NULL,
    notify_family_if_missed boolean NOT NULL DEFAULT true,
    version             int NOT NULL DEFAULT 1,
    created_by          text NOT NULL REFERENCES users(id),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    archived_at         timestamptz
);

CREATE TABLE medication_doses (
    id                  text PRIMARY KEY,
    care_recipient_id   text NOT NULL REFERENCES care_recipients(id),
    plan_id             text REFERENCES medication_plans(id),
    plan_name           text NOT NULL,
    scheduled_at        timestamptz NOT NULL,
    status              text NOT NULL CHECK (status IN ('confirmed', 'missed')),
    confirmed_at        timestamptz,
    evidence            text CHECK (evidence IN ('selfReported', 'familyReported', 'pillboxOpened'))
);
CREATE INDEX medication_doses_recipient_time ON medication_doses (care_recipient_id, scheduled_at);

CREATE TABLE care_events (
    id                  text PRIMARY KEY,
    care_recipient_id   text NOT NULL REFERENCES care_recipients(id),
    title               text NOT NULL,
    severity            text NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    status              text NOT NULL CHECK (status IN ('pending', 'claimed', 'resolved')),
    location            text NOT NULL,
    occurred_at         timestamptz NOT NULL,
    resolution          text,
    version             int NOT NULL DEFAULT 1
);
CREATE INDEX care_events_recipient_time ON care_events (care_recipient_id, occurred_at);

-- 报告与投递 ------------------------------------------------------------

-- 报告是生成时刻的不可变快照；内容更正必须生成新报告。
CREATE TABLE health_reports (
    id                  text PRIMARY KEY,
    care_recipient_id   text NOT NULL REFERENCES care_recipients(id),
    schema_version      int  NOT NULL,
    period_start        timestamptz NOT NULL,
    period_end          timestamptz NOT NULL,
    generated_at        timestamptz NOT NULL,
    requested_by        text NOT NULL REFERENCES users(id),
    snapshot            jsonb NOT NULL,
    snapshot_sha256     bytea NOT NULL,
    pdf_object_key      text,
    CHECK (period_end > period_start)
);
CREATE INDEX health_reports_recipient ON health_reports (care_recipient_id, generated_at DESC);

CREATE TABLE report_deliveries (
    id                  text PRIMARY KEY,
    report_id           text NOT NULL REFERENCES health_reports(id),
    doctor_id           text NOT NULL REFERENCES doctors(id),
    authorization_id    text NOT NULL REFERENCES doctor_authorizations(id),
    status              text NOT NULL CHECK (status IN ('sent', 'read', 'replied', 'revoked')),
    sent_at             timestamptz NOT NULL DEFAULT now(),
    read_at             timestamptz,
    revoked_at          timestamptz,
    version             int NOT NULL DEFAULT 1,
    UNIQUE (report_id, doctor_id)
);
CREATE INDEX report_deliveries_doctor_inbox ON report_deliveries (doctor_id, status, sent_at DESC);

CREATE TABLE report_replies (
    id                  text PRIMARY KEY,
    delivery_id         text NOT NULL REFERENCES report_deliveries(id),
    doctor_id           text NOT NULL REFERENCES doctors(id),
    content             text NOT NULL CHECK (length(content) BETWEEN 1 AND 4000),
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- 审计 ------------------------------------------------------------------

-- 只追加。医生的每次查看、导出、打印都写一条，家属端「访问记录」从这里读取。
CREATE TABLE audit_logs (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at         timestamptz NOT NULL DEFAULT now(),
    actor_type          text NOT NULL CHECK (actor_type IN ('family', 'doctor', 'admin', 'system')),
    actor_id            text NOT NULL,
    action              text NOT NULL,
    resource_type       text NOT NULL,
    resource_id         text NOT NULL,
    care_recipient_id   text,
    request_id          text,
    ip                  inet,
    user_agent          text
);
CREATE INDEX audit_logs_recipient_time ON audit_logs (care_recipient_id, occurred_at DESC);

COMMIT;
