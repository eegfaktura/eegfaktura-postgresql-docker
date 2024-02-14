/** eegfakuta-postgresql
* Postgrsql Container for eegfaktura
* Copyright (C) 2023 Verein zur Förderung von Erneuerbaren Energiegemeinschaften (eegfaktura@vfeeg.org)
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero General Public License for more details.
*
* You should have received a copy of the GNU Affero General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
**/

/* Change Database to $DB_DATABASE */
/* PLEASE DO NOT EDIT */
/* Target Datababase is automatically replaced by 01_set_environment.sh script */
\c eegfaktura;
/* END PLEASE DO NOT EDIT */

CREATE TABLE IF NOT EXISTS base.EEG
(
    tenant               VARCHAR PRIMARY KEY,
    name                 TEXT    NOT NULL,
    description          VARCHAR(40),
    periods              JSON             DEFAULT ('[]'),
    "rcNumber"           TEXT    NOT NULL,
    area                 TEXT    NOT NULL, /* Ortsgebiet (LOCAL | REGIONAL) | BEG | GEA */
    legal                TEXT    NOT NULL DEFAULT 'verein', /* Unternehmensform ("verein" | "genossenschaft" | "geselschaft") */
    gridoperator_code    TEXT    NOT NULL,
    gridoperator_name    TEXT    NOT NULL,
    "communityId"        TEXT    NOT NULL,
    "businessNr"         TEXT,
    "allocationMode"     TEXT    NOT NULL DEFAULT 'DYNAMIC', /* "DYNAMIC" | "STATIC" */
    "settlementInterval" TEXT    NOT NULL DEFAULT 'MONTHLY', /* "MONTHLY" | "QUARTER" | "BIANNUAL" | "ANNUAL" */
    "providerBusinessNr" INTEGER,
    "taxNumber"          TEXT,
    "vatNumber"          TEXT,
    subjecttovat         BOOLEAN,
    "contactPerson"      TEXT,
    -- Address Info
    street               TEXT    NOT NULL,
    "streetNumber"       TEXT    NOT NULL,
    city                 TEXT    NOT NULL,
    zip                  TEXT    NOT NULL,
    -- Account Info
    iban                 TEXT,
    owner                TEXT,
    sepa                 BOOLEAN NOT NULL DEFAULT false,
    "bankName"           TEXT,
    -- Contact Info
    phone                TEXT,
    email                TEXT    NOT NULL,
    website              TEXT,

    online               BOOLEAN NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_eeg ON base.EEG (tenant, name, "rcNumber");

CREATE TABLE IF NOT EXISTS base.tariff
(
    id                    UUID    NOT NULL DEFAULT uuid_generate_v4(),
    tenant                VARCHAR NOT NULL,
    type                  VARCHAR NOT NULL, /* 'tariff type like EEG, VZP, EZP, AKONTO' */
    name                  TEXT    NOT NULL,
    "billingPeriod"       TEXT             DEFAULT 'monthly',
    "useVat"              BOOLEAN          DEFAULT FALSE,
    "vatInPercent"        NUMERIC,
    "accountNetAmount"    NUMERIC,
    "accountGrossAmount"  NUMERIC,
    "participantFee"      FLOAT,
    "baseFee"             FLOAT   NOT NULL,
    "freeKWh"             INTEGER,
    "businessNr"          INTEGER,
    "createdBy"           TEXT,
    "createdDate"         DATE,
    "lastModifiedDate"    DATE,
    version               INTEGER,
    "centPerKWh"          FLOAT,
    discount              INTEGER,
    status                TEXT    NOT NULL DEFAULT 'ACTIVE', /* ACTIVE | INACTIVE */
    "inactiveSince"       DATE,
    "meteringPointFee"    FLOAT,
    "useMeteringPointFee" BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT TariffPK PRIMARY KEY (id, version)
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_tariff ON base.tariff (id, tenant, name, type, version);

CREATE TABLE IF NOT EXISTS base.participant
(
    id                      UUID    NOT NULL DEFAULT uuid_generate_v4(),
    "participantNumber"     VARCHAR,
    tenant                  VARCHAR NOT NULL,
    firstname               VARCHAR NOT NULL,
    lastname                VARCHAR NOT NULL,
    role                    VARCHAR NOT NULL DEFAULT 'EEG_USER', /* 'EEG_USER' | 'EEG_ADMIN' */
    "businessRole"          VARCHAR NOT NULL DEFAULT 'EEG_PRIVATE', /* 'EEG_PRIVATE' | 'EEG_BUSINESS' */
    "titleBefore"           VARCHAR,
    "titleAfter"            VARCHAR,
    "participantSince"      DATE    NOT NULL DEFAULT now(),
    "vatNumber"             VARCHAR,
    "taxNumber"             VARCHAR,
    "companyRegisterNumber" VARCHAR,
    status                  VARCHAR NOT NULL DEFAULT 'NEW', /* 'NEW' | 'PENDING' | 'ACCEPTED' | 'ACTIVE' | 'INACTIVE' | 'ARCHIVED' | 'REJECTED' */
    "createdBy"             VARCHAR NOT NULL,
    "createdDate"           DATE             DEFAULT now(),
    "lastModifiedBy"        VARCHAR NOT NULL,
    "lastModifiedDate"      DATE             DEFAULT now(),
    version                 INTEGER          DEFAULT 1,
    "tariffId"              uuid,
    CONSTRAINT ParticipantPK PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_participant_tenant ON base.participant (id, tenant, version);

CREATE TABLE IF NOT EXISTS base.contactdetail
(
    id             UUID NOT NULL DEFAULT uuid_generate_v4(),
    participant_id UUID NOT NULL,
    email          TEXT,
    phone          TEXT,
    CONSTRAINT contactdetailsPK PRIMARY KEY (id),
    CONSTRAINT FK_ParticipantDetail FOREIGN KEY (participant_id) REFERENCES base.participant (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS base.address
(
    id             UUID NOT NULL DEFAULT uuid_generate_v4(),
    participant_id UUID NOT NULL,
    type           TEXT NOT NULL DEFAULT 'RESIDENCE', /*Address-Types: 'RESIDENCE' | 'BILLING' */
    street         TEXT,
    "streetNumber" TEXT,
    city           TEXT,
    zip            TEXT,
    CONSTRAINT addressPK PRIMARY KEY (id),
    CONSTRAINT FK_ParticipantAddress FOREIGN KEY (participant_id) REFERENCES base.participant (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS base.bankaccount
(
    id             UUID NOT NULL DEFAULT uuid_generate_v4(),
    participant_id UUID NOT NULL,
    iban           TEXT,
    owner          TEXT,
    "bankName"     TEXT,
    CONSTRAINT bankaccountPK PRIMARY KEY (id),
    CONSTRAINT FK_ParticipantBankaccount FOREIGN KEY (participant_id) REFERENCES base.participant (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS base.meteringpoint
(
    metering_point_id  TEXT      NOT NULL,
    participant_id     UUID      NOT NULL,
    tenant             TEXT      NOT NULL,
    grid_operator_name VARCHAR,
    grid_operator_id   VARCHAR,
    transformer        TEXT,
    direction          TEXT      NOT NULL DEFAULT 'CONSUMPTION', /* 'GENERATION' | 'CONSUMPTION' */
    status             TEXT      NOT NULL DEFAULT 'NEW', /* "NEW" | "PENDING" | "ACCEPTED" | "ACTIVE" | "INACTIVE" */
    tariff_id          UUID,
    inverterid         TEXT,
    "equipmentNumber"  TEXT,
    "equipmentName"    TEXT,
    street             TEXT,
    "streetNumber"     TEXT,
    city               TEXT,
    zip                TEXT,
    "registeredSince"  DATE      NOT NULL DEFAULT now(),
    "modifiedAt"       TIMESTAMP NOT NULL DEFAULT now(),
    "modifiedBy"       TEXT,
    activeSince        TIMESTAMP NOT NULL DEFAULT now(),
    inactiveSince      TIMESTAMP NOT NULL DEFAULT Date('2999-12-31'),
    active             INT       NOT NULL DEFAULT 1,
    flag               INT       NOT NULL DEFAULT 1,
    CONSTRAINT meteringpointPK PRIMARY KEY (metering_point_id, tenant, participant_id),
    CONSTRAINT FK_ParticipantMeteringpoint FOREIGN KEY (participant_id) REFERENCES base.participant (id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_meteringpoint_active ON base.meteringpoint (metering_point_id, tenant, active) where active = 1;


CREATE TABLE IF NOT EXISTS base.notification
(
    id           SERIAL PRIMARY KEY,
    tenant       TEXT      NOT NULL,
    type         TEXT      NOT NULL DEFAULT 'MESSAGE',/* MESSAGE TYPE DESCRIBE 'ERROR' | 'MESSAGE' | 'NOTIFICATION' */
    notification json      NOT NULL DEFAULT '{}',
    date         TIMESTAMP NOT NULL DEFAULT now(),
    role         VARCHAR   NOT NULL DEFAULT 'ADMIN' /* 'USER' | 'ADMIN' */
);

CREATE TABLE IF NOT EXISTS base.processhistory
(
    id               UUID      NOT NULL PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant           TEXT      NOT NULL,
    "conversationId" TEXT      NOT NULL,
    type             TEXT      NOT NULL,
    date             TIMESTAMP NOT NULL             DEFAULT now(),
    issuer           TEXT      NOT NULL,
    message          json      NOT NULL             DEFAULT '{}',
    direction        TEXT      NOT NULL             DEFAULT 'OUT', /* MESSAGE DIRECTION 'OUT' | 'IN' */
    protocol         VARCHAR
);

CREATE TABLE IF NOT EXISTS base.gridoperators
(
    id   VARCHAR NOT NULL,
    name VARCHAR NOT NULL,
    CONSTRAINT PK_GridOperators PRIMARY KEY (id, name)
);

CREATE VIEW base.activeTariff AS
SELECT id,
       name,
       tenant,
       "billingPeriod",
       "useVat",
       "vatInPercent",
       "accountNetAmount",
       "accountGrossAmount",
       "participantFee",
       "baseFee",
       "businessNr",
       version,
       type,
       "centPerKWh",
       discount,
       "freeKWh",
       "meteringPointFee",
       "useMeteringPointFee"
FROM base.tariff,
     (SELECT id as tid, MAX(version) as tversion FROM base.tariff GROUP BY id) as x
WHERE id = x.tid
  AND version = x.tversion
  AND status != 'ARCHIVED';

CREATE VIEW
    base.billing_masterdata AS
SELECT p.id                                                      participant_id,
       p."titleBefore"                                           participant_title_before,
       p.firstname                                               participant_firstname,
       p."participantNumber"                                     participant_number,
       p.lastname                                                participant_lastname,
       p."titleAfter"                                            participant_title_after,
       p."vatNumber"                                             participant_vat_id,
       p."taxNumber"                                             participant_tax_id,
       p."companyRegisterNumber"                                 participant_company_register_number,
       p."participantNumber"                                     participant_sepa_mandate_reference,
       p."participantSince"                                      participant_sepa_mandate_issue_date,
       pm.metering_point_id                                      metering_point_id,
       pm."equipmentNumber"                                      equipment_number,
       pm."equipmentName"                                        metering_equipment_name,
       (CASE WHEN pm.direction = 'GENERATION' THEN 0 ELSE 1 END) metering_point_type,
       c.tenant                                                  eec_id,
       c."rcNumber"                                              tenant_id,
       c.description                                             eec_name,
       c."vatNumber"                                             eec_vat_id,
       c."taxNumber"                                             eec_tax_id,
       c."businessNr"                                            eec_company_register_number,
       c.subjecttovat                                            eec_subject_to_vat,
       c.phone                                                   eec_phone,
       c.email                                                   eec_email,
       c.website                                                 eec_website,
       concat(c.street, ' ', c."streetNumber")                   eec_street,
       c.zip                                                     eec_zip_code,
       c.city                                                    eec_city,
       concat(p_address.street, ' ', p_address."streetNumber")   participant_street,
       p_address.zip                                             participant_zip_code,
       p_address.city                                            participant_city,
       t.type                                                    tariff_type,
       t.name                                                    tariff_name,
       t."billingPeriod"                                         tariff_billing_period,
       t."useVat"                                                tariff_use_vat,
       t."vatInPercent"                                          tariff_vat_in_percent,
       t."useMeteringPointFee"                                   tariff_use_metering_point_fee,
       t."meteringPointFee"                                      tariff_metering_point_fee,
       COALESCE(tp."participantFee", 0)                          tariff_participant_fee,
       COALESCE(tp."name", '')                                   tariff_participant_fee_name,
       COALESCE(tp."useVat", false)                              tariff_participant_fee_use_vat,
       COALESCE(tp."vatInPercent", 0)                            tariff_participant_fee_vat_in_percent,
       COALESCE(tp.discount, 0)                                  tariff_participant_fee_discount,
       t."baseFee"                                               tariff_basic_fee,
       t.discount                                                tariff_discount,
       t."centPerKWh"                                            tariff_working_fee_per_consumedkwh,
       t."centPerKWh"                                            tariff_credit_amount_per_producedkwh,
       t."freeKWh"                                               tariff_freekwh,
       COALESCE(b."bankName", '')                                participant_bank_name,
       b.iban                                                    participant_bank_iban,
       b.owner                                                   participant_bank_owner,
       o.email                                                   participant_email,
       COALESCE(c."bankName", '')                                eec_bank_name,
       c.iban                                                    eec_bank_iban,
       c.owner                                                   eec_bank_owner
FROM base.participant p
         LEFT JOIN base.eeg c ON c.tenant = p.tenant
         LEFT JOIN base.meteringpoint pm ON pm.participant_id = p.id
         LEFT JOIN base.address p_address ON p.id = p_address.participant_id AND p_address.type = 'BILLING'
         LEFT JOIN base.activetariff t ON t.id = pm.tariff_id
         LEFT JOIN base.activetariff tp ON tp.id = p."tariffId" AND tp.type = 'EEG'
         LEFT JOIN base.bankaccount b ON b.participant_id = p.id
         LEFT JOIN base.contactdetail o ON o.participant_id = p.id;

