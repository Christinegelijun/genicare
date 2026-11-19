-- 科室、排班、预约与医生在线状态（接 0001_init.sql）

BEGIN;

CREATE TABLE departments (
    id              text PRIMARY KEY,
    name            text NOT NULL UNIQUE,
    intro           text NOT NULL DEFAULT '',
    sort_order      int  NOT NULL DEFAULT 0
);

ALTER TABLE doctors
    ADD COLUMN IF NOT EXISTS department_id text REFERENCES departments(id),
    ADD COLUMN IF NOT EXISTS specialties   text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS is_admin      boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS presence      text NOT NULL DEFAULT 'offline'
        CHECK (presence IN ('online', 'away', 'offline'));

CREATE TABLE doctor_shifts (
    id                  text PRIMARY KEY,
    doctor_id           text NOT NULL REFERENCES doctors(id),
    starts_at           timestamptz NOT NULL,
    ends_at             timestamptz NOT NULL,
    slot_minutes        int NOT NULL CHECK (slot_minutes BETWEEN 10 AND 120),
    capacity_per_slot   int NOT NULL CHECK (capacity_per_slot BETWEEN 1 AND 20),
    modes               text[] NOT NULL,
    CHECK (ends_at > starts_at)
);
CREATE INDEX doctor_shifts_doctor_time ON doctor_shifts (doctor_id, starts_at);

CREATE TABLE consult_appointments (
    id                  text PRIMARY KEY,
    care_recipient_id   text NOT NULL REFERENCES care_recipients(id),
    patient_name        text NOT NULL,
    doctor_id           text NOT NULL REFERENCES doctors(id),
    doctor_name         text NOT NULL,
    department_name     text NOT NULL,
    shift_id            text NOT NULL REFERENCES doctor_shifts(id),
    slot_index          int  NOT NULL CHECK (slot_index >= 0),
    starts_at           timestamptz NOT NULL,
    mode                text NOT NULL CHECK (mode IN ('text', 'phone', 'video')),
    status              text NOT NULL
                        CHECK (status IN ('booked', 'inConsultation', 'completed', 'cancelled', 'noShow')),
    booked_by           text NOT NULL,
    note                text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    version             int NOT NULL DEFAULT 1
);
CREATE INDEX consult_appointments_doctor_day
    ON consult_appointments (doctor_id, starts_at);
CREATE INDEX consult_appointments_patient
    ON consult_appointments (care_recipient_id, starts_at DESC);

-- 同一号源同一时段，活跃预约数由应用层按 capacity_per_slot 校验；
-- 同日同一患者对同一医生只能有一个活跃预约，也由应用层校验。

COMMIT;
