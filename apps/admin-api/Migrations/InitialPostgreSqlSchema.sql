CREATE TABLE departments (
    id text NOT NULL,
    name text NOT NULL,
    CONSTRAINT "PK_departments" PRIMARY KEY (id)
);

CREATE TABLE events (
    id uuid NOT NULL,
    title text NOT NULL,
    description text,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    lat double precision,
    lng double precision,
    location_text text,
    is_published boolean NOT NULL DEFAULT TRUE,
    CONSTRAINT "PK_events" PRIMARY KEY (id)
);

CREATE TABLE issued_tokens (
    jti text NOT NULL,
    subject text NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT "PK_issued_tokens" PRIMARY KEY (jti)
);

CREATE TABLE oc_days (
    id uuid NOT NULL,
    date date NOT NULL,
    name text,
    CONSTRAINT "PK_oc_days" PRIMARY KEY (id)
);

CREATE TABLE one_time_login_codes (
    id uuid NOT NULL,
    code_hash text NOT NULL,
    event_id uuid NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    used_by_uuid uuid,
    created_at timestamp with time zone NOT NULL,
    CONSTRAINT "PK_one_time_login_codes" PRIMARY KEY (id)
);

CREATE TABLE revoked_jti (
    jti text NOT NULL,
    revoked_at timestamp with time zone NOT NULL,
    reason text,
    revoked_by_user_id text,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT "PK_revoked_jti" PRIMARY KEY (jti)
);

CREATE TABLE spots (
    id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    tags text[],
    lat double precision,
    lng double precision,
    is_published boolean NOT NULL DEFAULT TRUE,
    updated_at timestamp with time zone NOT NULL,
    content_assets text,
    model_ref text,
    CONSTRAINT "PK_spots" PRIMARY KEY (id)
);

CREATE TABLE visit_logs (
    id uuid NOT NULL,
    session_id text NOT NULL,
    event_type text NOT NULL,
    spot_code text,
    payload_json text,
    occurred_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL,
    location_lat double precision,
    location_lng double precision,
    location_accuracy double precision,
    prev_hash text,
    hash text,
    hash_alg text,
    chain_id text,
    CONSTRAINT "PK_visit_logs" PRIMARY KEY (id)
);

CREATE TABLE open_campus_timeslots (
    id uuid NOT NULL,
    event_id uuid NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT "PK_open_campus_timeslots" PRIMARY KEY (id),
    CONSTRAINT "FK_open_campus_timeslots_events_event_id" FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE
);

CREATE TABLE exhibits (
    id uuid NOT NULL,
    name text NOT NULL,
    spot_id uuid NOT NULL,
    department_id text NOT NULL,
    description text,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    CONSTRAINT "PK_exhibits" PRIMARY KEY (id),
    CONSTRAINT "FK_exhibits_departments_department_id" FOREIGN KEY (department_id) REFERENCES departments (id) ON DELETE CASCADE,
    CONSTRAINT "FK_exhibits_spots_spot_id" FOREIGN KEY (spot_id) REFERENCES spots (id) ON DELETE CASCADE
);

CREATE TABLE qr_issues (
    id uuid NOT NULL,
    event_id uuid NOT NULL,
    timeslot_id uuid NOT NULL,
    token_hash text NOT NULL,
    payload_snapshot_json jsonb NOT NULL,
    issued_by_admin_id text NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    revoke_reason text,
    scan_count integer NOT NULL DEFAULT 0,
    last_scanned_at timestamp with time zone,
    CONSTRAINT "PK_qr_issues" PRIMARY KEY (id),
    CONSTRAINT "FK_qr_issues_events_event_id" FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE,
    CONSTRAINT "FK_qr_issues_open_campus_timeslots_timeslot_id" FOREIGN KEY (timeslot_id) REFERENCES open_campus_timeslots (id) ON DELETE CASCADE
);

CREATE TABLE timeslot_exhibits (
    timeslot_id uuid NOT NULL,
    exhibit_id uuid NOT NULL,
    sort_order integer NOT NULL,
    CONSTRAINT "PK_timeslot_exhibits" PRIMARY KEY (timeslot_id, exhibit_id),
    CONSTRAINT "FK_timeslot_exhibits_exhibits_exhibit_id" FOREIGN KEY (exhibit_id) REFERENCES exhibits (id) ON DELETE CASCADE,
    CONSTRAINT "FK_timeslot_exhibits_open_campus_timeslots_timeslot_id" FOREIGN KEY (timeslot_id) REFERENCES open_campus_timeslots (id) ON DELETE CASCADE
);

CREATE INDEX "IX_exhibits_department_id" ON exhibits (department_id);

CREATE INDEX "IX_exhibits_spot_id" ON exhibits (spot_id);

CREATE INDEX "IX_issued_tokens_subject" ON issued_tokens (subject);

CREATE UNIQUE INDEX "IX_oc_days_date" ON oc_days (date);

CREATE UNIQUE INDEX "IX_one_time_login_codes_code_hash" ON one_time_login_codes (code_hash);

CREATE INDEX "IX_open_campus_timeslots_event_id" ON open_campus_timeslots (event_id);

CREATE INDEX "IX_qr_issues_event_id" ON qr_issues (event_id);

CREATE INDEX "IX_qr_issues_timeslot_id" ON qr_issues (timeslot_id);

CREATE UNIQUE INDEX "IX_qr_issues_token_hash" ON qr_issues (token_hash);

CREATE UNIQUE INDEX "IX_spots_code" ON spots (code);

CREATE INDEX "IX_timeslot_exhibits_exhibit_id" ON timeslot_exhibits (exhibit_id);

CREATE INDEX ix_visit_logs_chain_id_created_at ON visit_logs (chain_id, created_at);
