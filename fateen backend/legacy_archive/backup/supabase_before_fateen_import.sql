--
-- PostgreSQL database dump
--

\restrict Dt1ccbY4l0A4trNO4gU7lplT1JhywqfKkadSmu7afi5o494PBO1NkphBfjag1sp

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.10 (Debian 17.10-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.audit_log_entries (instance_id, id, payload, created_at, ip_address) FROM stdin;
\.


--
-- Data for Name: custom_oauth_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.custom_oauth_providers (id, provider_type, identifier, name, client_id, client_secret, acceptable_client_ids, scopes, pkce_enabled, attribute_mapping, authorization_params, enabled, email_optional, issuer, discovery_url, skip_nonce_check, cached_discovery, discovery_cached_at, authorization_url, token_url, userinfo_url, jwks_uri, created_at, updated_at, custom_claims_allowlist) FROM stdin;
\.


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.flow_state (id, user_id, auth_code, code_challenge_method, code_challenge, provider_type, provider_access_token, provider_refresh_token, created_at, updated_at, authentication_method, auth_code_issued_at, invite_token, referrer, oauth_client_state_id, linking_target_id, email_optional) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) FROM stdin;
\.


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) FROM stdin;
\.


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.instances (id, uuid, raw_base_config, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_clients (id, client_secret_hash, registration_type, redirect_uris, grant_types, client_name, client_uri, logo_uri, created_at, updated_at, deleted_at, client_type, token_endpoint_auth_method) FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sessions (id, user_id, created_at, updated_at, factor_id, aal, not_after, refreshed_at, user_agent, ip, tag, oauth_client_id, refresh_token_hmac_key, refresh_token_counter, scopes) FROM stdin;
\.


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_amr_claims (session_id, created_at, updated_at, authentication_method, id) FROM stdin;
\.


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret, phone, last_challenged_at, web_authn_credential, web_authn_aaguid, last_webauthn_challenge_data) FROM stdin;
\.


--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_challenges (id, factor_id, created_at, verified_at, ip_address, otp_code, web_authn_session_data) FROM stdin;
\.


--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_authorizations (id, authorization_id, client_id, user_id, redirect_uri, scope, state, resource, code_challenge, code_challenge_method, response_type, status, authorization_code, created_at, expires_at, approved_at, nonce) FROM stdin;
\.


--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_client_states (id, provider_type, code_verifier, created_at) FROM stdin;
\.


--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_consents (id, user_id, client_id, scopes, granted_at, revoked_at) FROM stdin;
\.


--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.one_time_tokens (id, user_id, token_type, token_hash, relates_to, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.refresh_tokens (instance_id, id, token, user_id, revoked, created_at, updated_at, parent, session_id) FROM stdin;
\.


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_providers (id, resource_id, created_at, updated_at, disabled) FROM stdin;
\.


--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_providers (id, sso_provider_id, entity_id, metadata_xml, metadata_url, attribute_mapping, created_at, updated_at, name_id_format) FROM stdin;
\.


--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_relay_states (id, sso_provider_id, request_id, for_email, redirect_to, created_at, updated_at, flow_state_id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.schema_migrations (version) FROM stdin;
20171026211738
20171026211808
20171026211834
20180103212743
20180108183307
20180119214651
20180125194653
00
20210710035447
20210722035447
20210730183235
20210909172000
20210927181326
20211122151130
20211124214934
20211202183645
20220114185221
20220114185340
20220224000811
20220323170000
20220429102000
20220531120530
20220614074223
20220811173540
20221003041349
20221003041400
20221011041400
20221020193600
20221021073300
20221021082433
20221027105023
20221114143122
20221114143410
20221125140132
20221208132122
20221215195500
20221215195800
20221215195900
20230116124310
20230116124412
20230131181311
20230322519590
20230402418590
20230411005111
20230508135423
20230523124323
20230818113222
20230914180801
20231027141322
20231114161723
20231117164230
20240115144230
20240214120130
20240306115329
20240314092811
20240427152123
20240612123726
20240729123726
20240802193726
20240806073726
20241009103726
20250717082212
20250731150234
20250804100000
20250901200500
20250903112500
20250904133000
20250925093508
20251007112900
20251104100000
20251111201300
20251201000000
20260115000000
20260121000000
20260219120000
20260302000000
20260625000000
\.


--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_domains (id, sso_provider_id, domain, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: webauthn_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_challenges (id, user_id, challenge_type, session_data, created_at, expires_at) FROM stdin;
\.


--
-- Data for Name: webauthn_credentials; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_credentials (id, user_id, credential_id, public_key, attestation_type, aaguid, sign_count, transports, backup_eligible, backed_up, friendly_name, created_at, updated_at, last_used_at) FROM stdin;
\.


--
-- Data for Name: lifecycle_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lifecycle_statuses (id, code, name, description, display_order, version_number, created_at, updated_at, deleted_at) FROM stdin;
1	ACTIVE	Active	Reference row is in service and eligible for use.	1	1	2026-08-10 11:12:51.728364+00	2026-08-10 11:12:51.728364+00	\N
2	DEPRECATED	Deprecated	No longer recommended; kept for history and referential integrity.	2	1	2026-08-10 11:12:51.728364+00	2026-08-10 11:12:51.728364+00	\N
3	ARCHIVED	Archived	Retired from use; preserved for audit and history.	3	1	2026-08-10 11:12:51.728364+00	2026-08-10 11:12:51.728364+00	\N
\.


--
-- Data for Name: allergen_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allergen_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
b4ef879c-7d2c-443b-9435-055c9a442fb7	FOOD_ALLERGEN	Food Allergen	\N	0	1	1	2026-08-11 00:13:04.177607+00	2026-08-11 00:13:04.177607+00	\N
8affd3a9-4bd2-49a8-9183-b276c4d24ab2	DIETARY_RESTRICTION	Dietary Restriction	\N	0	1	1	2026-08-11 00:13:04.177607+00	2026-08-11 00:13:04.177607+00	\N
\.


--
-- Data for Name: countries; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.countries (id, code, alpha_3, numeric_code, name, is_gcc_member, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: source_priorities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.source_priorities (id, code, name, rank, description, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: source_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.source_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
555ec644-ccf9-45e8-8b30-38881e08d886	MANUFACTURER	Manufacturer	\N	0	1	1	2026-08-11 00:13:04.851989+00	2026-08-11 00:13:04.851989+00	\N
8f49e711-945d-4718-8d7e-bd97c8964bc7	REGULATORY	Regulatory Authority	\N	0	1	1	2026-08-11 00:13:04.851989+00	2026-08-11 00:13:04.851989+00	\N
99a00982-9129-4753-afe3-60f56aae2875	DATABASE	Database	\N	0	1	1	2026-08-11 00:13:04.851989+00	2026-08-11 00:13:04.851989+00	\N
9bbc9037-983b-4ce1-81de-6cb6afc086f5	USER_SUBMITTED	User Submitted	\N	0	1	1	2026-08-11 00:13:04.851989+00	2026-08-11 00:13:04.851989+00	\N
6e5b8193-554e-40df-8be8-25c57c1da0be	IMPORT	Data Import	\N	0	1	1	2026-08-11 00:13:04.851989+00	2026-08-11 00:13:04.851989+00	\N
\.


--
-- Data for Name: data_sources; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.data_sources (id, code, name, description, source_type_id, priority_id, country_id, is_verified, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: allergens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allergens (id, allergen_type_id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: languages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.languages (id, code, name, native_name, is_rtl, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
c43b9ba9-e823-42b3-b031-2a9ec3ece457	en	English	English	f	1	1	2026-08-11 00:28:03.944019+00	2026-08-11 00:28:03.944019+00	\N
4b80bc8d-396c-406c-b479-2c4274fed94a	ar	Arabic	العربية	f	1	1	2026-08-11 00:28:03.944019+00	2026-08-11 00:28:03.944019+00	\N
\.


--
-- Data for Name: allergen_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allergen_translations (id, allergen_id, language_id, name, short_name, display_name, search_name, description, translation_status, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: role_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.role_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: audit_context; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_context (id, correlation_id, transaction_id, actor, role_id, source, ip_address, user_agent, started_at, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: change_sets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.change_sets (id, correlation_id, transaction_id, description, applied_at, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: allergens_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allergens_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, allergen_type_id, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: audit_event_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_event_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_log (id, change_set_id, event_type_id, entity_type, entity_id, previous_version, new_version, actor, role_id, source, ip_address, user_agent, correlation_id, transaction_id, logged_at, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: audit_events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_events (id, audit_log_id, event_type_id, entity_type, entity_id, previous_version, new_version, event_time, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: barcode_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.barcode_types (id, code, name, digit_length, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
dd4b4e39-c36a-42ab-9d26-293f7ab4397f	EAN13	EAN-13	\N	\N	0	1	1	2026-08-11 00:13:06.567188+00	2026-08-11 00:13:06.567188+00	\N
e62722da-881d-4fe6-babc-0183f1b58091	EAN8	EAN-8	\N	\N	0	1	1	2026-08-11 00:13:06.567188+00	2026-08-11 00:13:06.567188+00	\N
d1d5e53d-e6d2-410e-9d23-5a60eb4076dd	UPC_A	UPC-A	\N	\N	0	1	1	2026-08-11 00:13:06.567188+00	2026-08-11 00:13:06.567188+00	\N
f998e118-6203-4c39-9990-ec672bf2e708	UPC_E	UPC-E	\N	\N	0	1	1	2026-08-11 00:13:06.567188+00	2026-08-11 00:13:06.567188+00	\N
46a7907e-b29a-4807-b55e-aa67ff1c8abc	GTIN	GTIN	\N	\N	0	1	1	2026-08-11 00:13:06.567188+00	2026-08-11 00:13:06.567188+00	\N
\.


--
-- Data for Name: verification_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.verification_statuses (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
18ca5db5-32b8-4662-ac0d-be0b15cf0ba1	UNVERIFIED	Unverified	\N	0	1	1	2026-08-11 00:13:05.238317+00	2026-08-11 00:13:05.238317+00	\N
05408d93-519d-4e19-96d4-3a18bd1e85de	PENDING	Pending Verification	\N	0	1	1	2026-08-11 00:13:05.238317+00	2026-08-11 00:13:05.238317+00	\N
ed354cfc-f915-4805-842d-f035d8aacec5	VERIFIED	Verified	\N	0	1	1	2026-08-11 00:13:05.238317+00	2026-08-11 00:13:05.238317+00	\N
bcbb0479-e1eb-4177-bc2d-7d3fe2aba8b1	REJECTED	Rejected	\N	0	1	1	2026-08-11 00:13:05.238317+00	2026-08-11 00:13:05.238317+00	\N
\.


--
-- Data for Name: barcodes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.barcodes (id, barcode, barcode_type_id, verification_status_id, source_id, status_id, issued_country_id, confidence_level, version_number, created_by, updated_by, reviewed_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: barcodes_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.barcodes_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, barcode, barcode_type_id, verification_status_id, issued_country_id, status_id, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: brand_search_index; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.brand_search_index (id, brand_id, search_name, search_text, search_tokens, language_codes, search_rank, generated_at) FROM stdin;
\.


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.companies (id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: brands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.brands (id, company_id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: brand_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.brand_translations (id, brand_id, language_id, name, short_name, display_name, search_name, description, translation_status, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: brands_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.brands_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, company_id, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: companies_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.companies_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: company_search_index; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.company_search_index (id, company_id, search_name, search_text, search_tokens, language_codes, search_rank, generated_at) FROM stdin;
\.


--
-- Data for Name: company_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.company_translations (id, company_id, language_id, name, short_name, display_name, search_name, description, translation_status, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: evidence_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.evidence_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
c24d31c8-beda-4579-a81c-9ca44d430170	LABEL	Product Label	\N	0	1	1	2026-08-11 00:13:04.502262+00	2026-08-11 00:13:04.502262+00	\N
4748581e-f31c-4cbb-8ff7-58d898618f91	MANUFACTURER	Manufacturer	\N	0	1	1	2026-08-11 00:13:04.502262+00	2026-08-11 00:13:04.502262+00	\N
357c53ca-be84-4972-b455-fb4ba5bf7db2	OFFICIAL_SOURCE	Official Source	\N	0	1	1	2026-08-11 00:13:04.502262+00	2026-08-11 00:13:04.502262+00	\N
8b8071bd-53f4-4896-9587-d0114af571c3	DATABASE	Database Record	\N	0	1	1	2026-08-11 00:13:04.502262+00	2026-08-11 00:13:04.502262+00	\N
\.


--
-- Data for Name: relationship_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.relationship_types (id, code, name, description, is_directional, inverse_type_id, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	CONTAINS_INGREDIENT	Contains Ingredient	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
c816beeb-b723-40a1-9220-910125714e86	MAY_CONTAIN_INGREDIENT	May Contain Ingredient	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
18fa6ec8-afd8-40b2-b468-adc78bd6be12	CONTAINS_ALLERGEN	Contains Allergen	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
eb53c526-c4e5-47d0-827e-482d02a45b37	MAY_CONTAIN_ALLERGEN	May Contain Allergen	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
7489a8be-be9a-4f22-b472-96f7140295be	PRIMARY_BARCODE	Primary Barcode	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
e7a52d95-a5d2-471f-b106-926375279fa4	PACK_SIZE_VARIANT	Pack Size Variant	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
\.


--
-- Data for Name: entity_relationships; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.entity_relationships (id, subject_entity_type, subject_id, object_entity_type, object_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: entity_versions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.entity_versions (id, entity_type, entity_id, version_number, history_table, history_row_id, version_status, change_set_id, previous_version_id, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: health_flag_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.health_flag_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
c40db76f-62b3-4d19-a813-603112731cef	ALLERGY	Allergy	\N	0	1	1	2026-08-11 00:28:05.41058+00	2026-08-11 00:28:05.41058+00	\N
7ae7c564-719a-4320-a950-c2ec04c5cb02	CHRONIC_CONDITION	Chronic Condition	\N	0	1	1	2026-08-11 00:28:05.41058+00	2026-08-11 00:28:05.41058+00	\N
f8e96b2d-fbbb-4e78-bca9-1c8805dbf4ae	DIETARY	Dietary Restriction	\N	0	1	1	2026-08-11 00:28:05.41058+00	2026-08-11 00:28:05.41058+00	\N
62881f5c-4da1-4cc6-a0aa-69ec6f15a300	NUTRITION	Nutrition Related	\N	0	1	1	2026-08-11 00:28:05.41058+00	2026-08-11 00:28:05.41058+00	\N
\.


--
-- Data for Name: health_flags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.health_flags (id, health_flag_type_id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: health_flag_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.health_flag_translations (id, health_flag_id, language_id, name, short_name, display_name, search_name, description, translation_status, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: health_flags_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.health_flags_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, health_flag_type_id, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: image_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.image_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: images; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.images (id, image_type_id, source_id, language_id, storage_uri, content_hash, mime_type, width, height, file_size, status_id, metadata, version_number, created_by, updated_by, reviewed_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: images_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.images_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, image_type_id, language_id, storage_uri, content_hash, mime_type, width, height, file_size, metadata, status_id, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: ingredients; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredients (id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: ingredient_aliases; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredient_aliases (id, ingredient_id, alias, language_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: ingredient_allergens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredient_allergens (id, ingredient_id, allergen_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: ingredient_categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredient_categories (id, code, name, description, parent_id, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: ingredient_categories_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredient_categories_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, code, name, description, parent_id, display_order, status_id, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: ingredient_health_flags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredient_health_flags (id, ingredient_id, health_flag_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: ingredient_search_index; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredient_search_index (id, ingredient_id, search_name, search_text, search_tokens, language_codes, search_rank, generated_at) FROM stdin;
\.


--
-- Data for Name: ingredient_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredient_translations (id, ingredient_id, language_id, name, short_name, display_name, search_name, description, translation_status, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: ingredients_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredients_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: measurement_bases; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.measurement_bases (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: nutrition_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.nutrition_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
f2b7e53a-7967-4b55-a56b-ddeecdcc84c4	ENERGY	Energy	\N	0	1	1	2026-08-11 00:28:08.092247+00	2026-08-11 00:28:08.092247+00	\N
7335b58d-bcae-4c91-abba-eb5b1d339296	PROTEIN	Protein	\N	0	1	1	2026-08-11 00:28:08.092247+00	2026-08-11 00:28:08.092247+00	\N
7d654278-5571-4d46-bb30-55c471c095b1	CARBOHYDRATE	Carbohydrate	\N	0	1	1	2026-08-11 00:28:08.092247+00	2026-08-11 00:28:08.092247+00	\N
64deae22-bb51-4bae-b7a1-08d619902b8e	TOTAL_FAT	Total Fat	\N	0	1	1	2026-08-11 00:28:08.092247+00	2026-08-11 00:28:08.092247+00	\N
25133cf1-fea4-4e9f-82ac-d00efa505d6d	SATURATED_FAT	Saturated Fat	\N	0	1	1	2026-08-11 00:28:08.092247+00	2026-08-11 00:28:08.092247+00	\N
09ba73d7-19a4-439b-948b-1a2b7fc52dfc	TRANS_FAT	Trans Fat	\N	0	1	1	2026-08-11 00:28:08.092247+00	2026-08-11 00:28:08.092247+00	\N
28a38949-f7b3-4ea8-8456-92538dc8262d	SODIUM	Sodium	\N	0	1	1	2026-08-11 00:28:08.092247+00	2026-08-11 00:28:08.092247+00	\N
0fd49348-3025-4661-9f91-b1d860a7c1a2	SUGAR	Sugar	\N	0	1	1	2026-08-11 00:28:08.092247+00	2026-08-11 00:28:08.092247+00	\N
8d483349-3d04-4894-8a7b-979b8f0380dc	FIBER	Dietary Fiber	\N	0	1	1	2026-08-11 00:28:08.092247+00	2026-08-11 00:28:08.092247+00	\N
\.


--
-- Data for Name: nutrition_type_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.nutrition_type_translations (id, nutrition_type_id, language_id, name, short_name, display_name, search_name, description, translation_status, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: nutrition_types_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.nutrition_types_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, code, name, description, display_order, status_id, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: package_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.package_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
aa3666d3-234d-4ce7-87a7-26ccf072ac93	BOTTLE	Bottle	\N	0	1	1	2026-08-11 00:13:05.655222+00	2026-08-11 00:13:05.655222+00	\N
450d1161-4f47-45f3-97e2-539566e5aafb	BOX	Box	\N	0	1	1	2026-08-11 00:13:05.655222+00	2026-08-11 00:13:05.655222+00	\N
1646ce88-63a2-47b0-aaa0-e9613688b15a	CAN	Can	\N	0	1	1	2026-08-11 00:13:05.655222+00	2026-08-11 00:13:05.655222+00	\N
f9ee6fc5-d4b2-4e7e-898a-d33a120f1e3d	BAG	Bag	\N	0	1	1	2026-08-11 00:13:05.655222+00	2026-08-11 00:13:05.655222+00	\N
ff50981e-fcd4-4431-b38c-58ef3dea7e9b	CARTON	Carton	\N	0	1	1	2026-08-11 00:13:05.655222+00	2026-08-11 00:13:05.655222+00	\N
fe249e86-0cc7-4c8e-bc94-a5243f13567d	JAR	Jar	\N	0	1	1	2026-08-11 00:13:05.655222+00	2026-08-11 00:13:05.655222+00	\N
8f4c183c-fb10-4e6f-8f80-56f7a3066352	POUCH	Pouch	\N	0	1	1	2026-08-11 00:13:05.655222+00	2026-08-11 00:13:05.655222+00	\N
ff1c4c91-d191-4b58-8d1f-286d0e2c604d	OTHER	Other	\N	0	1	1	2026-08-11 00:13:05.655222+00	2026-08-11 00:13:05.655222+00	\N
\.


--
-- Data for Name: permission_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.permission_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: product_categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_categories (id, code, name, description, parent_id, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
acf8502c-2ea3-47d5-b10e-63bde2301d56	DAIRY	Dairy Products	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
5bebaca4-a5ad-4905-9f2f-ac5bbbf6bb5a	BAKERY	Bakery Products	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
5a7e8ade-4b8a-4026-9087-9dc1563e3160	BEVERAGES	Beverages	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
2caff78d-4a7d-4c5b-a5a5-5974b827d86e	SNACKS	Snacks	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
33d06796-7aec-46c0-afa1-c580eab2ef7d	CEREALS	Cereals	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
b15224b6-295d-401f-9322-81b4b78a7d47	SAUCES	Sauces and Condiments	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
5a2a9e5b-e5b3-48b8-acd0-9bac8cd40600	CANNED_FOOD	Canned Food	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
dc17b053-786e-421c-86ff-010fecd34c55	FROZEN_FOOD	Frozen Food	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
d06b316c-141c-42d2-964c-9b533c066618	CONFECTIONERY	Confectionery	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
3f45d4c9-63d9-4eae-b7ca-552e702ea628	BABY_FOOD	Baby Food	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
ee127547-9578-405e-9177-1227fdb57400	MEAT	Meat Products	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
34477817-c87f-4d49-a5ae-2187594227a6	SEAFOOD	Seafood	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
f047b785-2b16-4378-a1ed-8b704332e1b8	FRUITS	Fruits	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
b4f6a152-4a7f-4185-811f-76f968f74774	VEGETABLES	Vegetables	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
315baedd-adb6-4782-bf07-6ec27da60986	OTHER	Other	\N	\N	0	1	1	2026-08-11 00:28:04.638556+00	2026-08-11 00:28:04.638556+00	\N
68c21140-1bba-40e8-8c67-8e049d8cb86c	TEST_DAIRY	Test Dairy	\N	\N	0	1	1	2026-08-11 00:29:13.642605+00	2026-08-11 00:29:13.642605+00	\N
43b97eff-65e2-466a-bef8-6d1ee41f5287	TEST_SNACK	Test Snack	\N	\N	0	1	1	2026-08-11 00:29:13.642605+00	2026-08-11 00:29:13.642605+00	\N
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.products (id, brand_id, product_category_id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: product_allergens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_allergens (id, product_id, allergen_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: product_barcodes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_barcodes (id, product_id, barcode_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: product_barcodes_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_barcodes_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, product_id, barcode_id, relationship_type_id, evidence_type_id, effective_from, effective_to, verified_at, approved_at, status_id, deleted_at, created_at, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: product_categories_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_categories_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, code, name, description, parent_id, display_order, status_id, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: product_category_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_category_translations (id, product_category_id, language_id, name, short_name, display_name, search_name, description, translation_status, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: product_health_flags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_health_flags (id, product_id, health_flag_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: product_images; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_images (id, product_id, image_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: product_images_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_images_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, product_id, image_id, relationship_type_id, evidence_type_id, effective_from, effective_to, verified_at, approved_at, status_id, deleted_at, created_at, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: units; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.units (id, code, name, symbol, dimension, is_base_unit, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
45c69208-467c-4049-9c22-2b79ddd9f8e9	G	Gram	g	mass	t	1	1	2026-08-11 00:15:33.125181+00	2026-08-11 00:15:33.125181+00	\N
94c63c0a-5d55-4e18-b206-cf659d743231	KG	Kilogram	kg	mass	f	1	1	2026-08-11 00:15:33.125181+00	2026-08-11 00:15:33.125181+00	\N
fae562bd-275f-4d85-afbf-f1cfc6a43a6e	ML	Milliliter	ml	volume	t	1	1	2026-08-11 00:15:33.125181+00	2026-08-11 00:15:33.125181+00	\N
c0315aa4-401f-45e7-8df4-96154ca33c6a	L	Liter	L	volume	f	1	1	2026-08-11 00:15:33.125181+00	2026-08-11 00:15:33.125181+00	\N
28189bfe-81a7-436d-b51e-a3855941669d	MG	Milligram	mg	mass	f	1	1	2026-08-11 00:15:33.125181+00	2026-08-11 00:15:33.125181+00	\N
408296ef-b43f-4420-931f-52672f149434	PCS	Piece	pcs	count	t	1	1	2026-08-11 00:15:33.125181+00	2026-08-11 00:15:33.125181+00	\N
\.


--
-- Data for Name: product_ingredients; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_ingredients (id, product_id, ingredient_id, relationship_type_id, amount_value, unit_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: product_nutrition_values; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_nutrition_values (id, product_id, nutrition_type_id, relationship_type_id, amount_value, unit_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at, measurement_basis_id) FROM stdin;
\.


--
-- Data for Name: product_search_index; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_search_index (id, product_id, search_name, search_text, search_tokens, language_codes, search_rank, generated_at) FROM stdin;
\.


--
-- Data for Name: product_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.product_translations (id, product_id, language_id, name, short_name, display_name, search_name, description, translation_status, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: products_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.products_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, brand_id, product_category_id, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
\.


--
-- Data for Name: regions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.regions (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: regulatory_authorities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.regulatory_authorities (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schema_migrations (version, checksum, applied_at) FROM stdin;
\.


--
-- Data for Name: version_metadata; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.version_metadata (id, entity_version_id, key, value, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.schema_migrations (version, inserted_at) FROM stdin;
20211116024918	2026-08-11 15:32:54
20211116045059	2026-08-11 15:32:54
20211116050929	2026-08-11 15:32:54
20211116051442	2026-08-11 15:32:54
20211116212300	2026-08-11 15:32:54
20211116213355	2026-08-11 15:32:54
20211116213934	2026-08-11 15:32:54
20211116214523	2026-08-11 15:32:54
20211122062447	2026-08-11 15:32:54
20211124070109	2026-08-11 15:32:54
20211202204204	2026-08-11 15:32:54
20211202204605	2026-08-11 15:32:54
20211210212804	2026-08-11 15:32:54
20211228014915	2026-08-11 15:32:54
20220107221237	2026-08-11 15:32:54
20220228202821	2026-08-11 15:32:54
20220312004840	2026-08-11 15:32:54
20220603231003	2026-08-11 15:32:54
20220603232444	2026-08-11 15:32:54
20220615214548	2026-08-11 15:32:54
20220712093339	2026-08-11 15:32:54
20220908172859	2026-08-11 15:32:54
20220916233421	2026-08-11 15:32:54
20230119133233	2026-08-11 15:32:54
20230128025114	2026-08-11 15:32:54
20230128025212	2026-08-11 15:32:54
20230227211149	2026-08-11 15:32:54
20230228184745	2026-08-11 15:32:54
20230308225145	2026-08-11 15:32:54
20230328144023	2026-08-11 15:32:54
20231018144023	2026-08-11 15:32:54
20231204144023	2026-08-11 15:32:54
20231204144024	2026-08-11 15:32:54
20231204144025	2026-08-11 15:32:54
20240108234812	2026-08-11 15:32:54
20240109165339	2026-08-11 15:32:54
20240227174441	2026-08-11 15:32:54
20240311171622	2026-08-11 15:32:54
20240321100241	2026-08-11 15:32:54
20240401105812	2026-08-11 15:32:54
20240418121054	2026-08-11 15:32:54
20240523004032	2026-08-11 15:32:54
20240618124746	2026-08-11 15:32:54
20240801235015	2026-08-11 15:32:54
20240805133720	2026-08-11 15:32:54
20240827160934	2026-08-11 15:32:54
20240919163303	2026-08-11 15:32:54
20240919163305	2026-08-11 15:32:54
20241019105805	2026-08-11 15:32:54
20241030150047	2026-08-11 15:32:54
20241108114728	2026-08-11 15:32:54
20241121104152	2026-08-11 15:32:54
20241130184212	2026-08-11 15:32:54
20241220035512	2026-08-11 15:32:54
20241220123912	2026-08-11 15:32:54
20241224161212	2026-08-11 15:32:54
20250107150512	2026-08-11 15:32:54
20250110162412	2026-08-11 15:32:54
20250123174212	2026-08-11 15:32:54
20250128220012	2026-08-11 15:32:54
20250506224012	2026-08-11 15:32:54
20250523164012	2026-08-11 15:32:54
20250714121412	2026-08-11 15:32:54
20250905041441	2026-08-11 15:32:54
20251103001201	2026-08-11 15:32:54
20251120212548	2026-08-11 15:32:54
20251120215549	2026-08-11 15:32:54
20260218120000	2026-08-11 15:32:54
20260326120000	2026-08-11 15:32:54
20260514120000	2026-08-11 15:32:54
20260527120000	2026-08-11 15:32:54
20260528120000	2026-08-11 15:32:54
20260603120000	2026-08-11 15:32:54
20260605120000	2026-08-11 15:32:54
20260606110000	2026-08-11 15:32:54
20260616120000	2026-08-11 15:32:54
20260624120000	2026-08-11 15:32:54
20260626120000	2026-08-11 15:32:54
20260706120000	2026-08-11 15:32:54
20260707120000	2026-08-11 15:32:54
20260709120000	2026-08-11 15:32:54
\.


--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.subscription (id, subscription_id, entity, filters, claims, created_at, action_filter, selected_columns) FROM stdin;
\.


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets (id, name, owner, created_at, updated_at, public, avif_autodetection, file_size_limit, allowed_mime_types, owner_id, type) FROM stdin;
\.


--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_analytics (name, type, format, created_at, updated_at, id, deleted_at) FROM stdin;
\.


--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_vectors (id, type, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.migrations (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	e18db593bcde2aca2a408c4d1100f6abba2195df	2026-08-11 14:42:36.131519
1	initialmigration	6ab16121fbaa08bbd11b712d05f358f9b555d777	2026-08-11 14:42:36.153604
2	storage-schema	f6a1fa2c93cbcd16d4e487b362e45fca157a8dbd	2026-08-11 14:42:36.161058
3	pathtoken-column	2cb1b0004b817b29d5b0a971af16bafeede4b70d	2026-08-11 14:42:36.185236
4	add-migrations-rls	427c5b63fe1c5937495d9c635c263ee7a5905058	2026-08-11 14:42:36.201475
5	add-size-functions	79e081a1455b63666c1294a440f8ad4b1e6a7f84	2026-08-11 14:42:36.208714
6	change-column-name-in-get-size	ded78e2f1b5d7e616117897e6443a925965b30d2	2026-08-11 14:42:36.217434
7	add-rls-to-buckets	e7e7f86adbc51049f341dfe8d30256c1abca17aa	2026-08-11 14:42:36.225045
8	add-public-to-buckets	fd670db39ed65f9d08b01db09d6202503ca2bab3	2026-08-11 14:42:36.231871
9	fix-search-function	af597a1b590c70519b464a4ab3be54490712796b	2026-08-11 14:42:36.239086
10	search-files-search-function	b595f05e92f7e91211af1bbfe9c6a13bb3391e16	2026-08-11 14:42:36.246353
11	add-trigger-to-auto-update-updated_at-column	7425bdb14366d1739fa8a18c83100636d74dcaa2	2026-08-11 14:42:36.254621
12	add-automatic-avif-detection-flag	8e92e1266eb29518b6a4c5313ab8f29dd0d08df9	2026-08-11 14:42:36.261865
13	add-bucket-custom-limits	cce962054138135cd9a8c4bcd531598684b25e7d	2026-08-11 14:42:36.268701
14	use-bytes-for-max-size	941c41b346f9802b411f06f30e972ad4744dad27	2026-08-11 14:42:36.275795
15	add-can-insert-object-function	934146bc38ead475f4ef4b555c524ee5d66799e5	2026-08-11 14:42:36.299474
16	add-version	76debf38d3fd07dcfc747ca49096457d95b1221b	2026-08-11 14:42:36.306802
17	drop-owner-foreign-key	f1cbb288f1b7a4c1eb8c38504b80ae2a0153d101	2026-08-11 14:42:36.3135
18	add_owner_id_column_deprecate_owner	e7a511b379110b08e2f214be852c35414749fe66	2026-08-11 14:42:36.320438
19	alter-default-value-objects-id	02e5e22a78626187e00d173dc45f58fa66a4f043	2026-08-11 14:42:36.328398
20	list-objects-with-delimiter	cd694ae708e51ba82bf012bba00caf4f3b6393b7	2026-08-11 14:42:36.336508
21	s3-multipart-uploads	8c804d4a566c40cd1e4cc5b3725a664a9303657f	2026-08-11 14:42:36.344572
22	s3-multipart-uploads-big-ints	9737dc258d2397953c9953d9b86920b8be0cdb73	2026-08-11 14:42:36.358798
23	optimize-search-function	9d7e604cddc4b56a5422dc68c9313f4a1b6f132c	2026-08-11 14:42:36.369738
24	operation-function	8312e37c2bf9e76bbe841aa5fda889206d2bf8aa	2026-08-11 14:42:36.376691
25	custom-metadata	d974c6057c3db1c1f847afa0e291e6165693b990	2026-08-11 14:42:36.383505
26	objects-prefixes	215cabcb7f78121892a5a2037a09fedf9a1ae322	2026-08-11 14:42:36.390511
27	search-v2	859ba38092ac96eb3964d83bf53ccc0b141663a6	2026-08-11 14:42:36.396897
28	object-bucket-name-sorting	c73a2b5b5d4041e39705814fd3a1b95502d38ce4	2026-08-11 14:42:36.403554
29	create-prefixes	ad2c1207f76703d11a9f9007f821620017a66c21	2026-08-11 14:42:36.409884
30	update-object-levels	2be814ff05c8252fdfdc7cfb4b7f5c7e17f0bed6	2026-08-11 14:42:36.416512
31	objects-level-index	b40367c14c3440ec75f19bbce2d71e914ddd3da0	2026-08-11 14:42:36.425121
32	backward-compatible-index-on-objects	e0c37182b0f7aee3efd823298fb3c76f1042c0f7	2026-08-11 14:42:36.431597
33	backward-compatible-index-on-prefixes	b480e99ed951e0900f033ec4eb34b5bdcb4e3d49	2026-08-11 14:42:36.438156
34	optimize-search-function-v1	ca80a3dc7bfef894df17108785ce29a7fc8ee456	2026-08-11 14:42:36.444613
35	add-insert-trigger-prefixes	458fe0ffd07ec53f5e3ce9df51bfdf4861929ccc	2026-08-11 14:42:36.451272
36	optimise-existing-functions	6ae5fca6af5c55abe95369cd4f93985d1814ca8f	2026-08-11 14:42:36.457638
37	add-bucket-name-length-trigger	3944135b4e3e8b22d6d4cbb568fe3b0b51df15c1	2026-08-11 14:42:36.464172
38	iceberg-catalog-flag-on-buckets	02716b81ceec9705aed84aa1501657095b32e5c5	2026-08-11 14:42:36.471268
39	add-search-v2-sort-support	6706c5f2928846abee18461279799ad12b279b78	2026-08-11 14:42:36.484197
40	fix-prefix-race-conditions-optimized	7ad69982ae2d372b21f48fc4829ae9752c518f6b	2026-08-11 14:42:36.490564
41	add-object-level-update-trigger	07fcf1a22165849b7a029deed059ffcde08d1ae0	2026-08-11 14:42:36.497208
42	rollback-prefix-triggers	771479077764adc09e2ea2043eb627503c034cd4	2026-08-11 14:42:36.503644
43	fix-object-level	84b35d6caca9d937478ad8a797491f38b8c2979f	2026-08-11 14:42:36.510113
44	vector-bucket-type	99c20c0ffd52bb1ff1f32fb992f3b351e3ef8fb3	2026-08-11 14:42:36.516999
45	vector-buckets	049e27196d77a7cb76497a85afae669d8b230953	2026-08-11 14:42:36.52394
46	buckets-objects-grants	fedeb96d60fefd8e02ab3ded9fbde05632f84aed	2026-08-11 14:42:36.537942
47	iceberg-table-metadata	649df56855c24d8b36dd4cc1aeb8251aa9ad42c2	2026-08-11 14:42:36.54527
48	iceberg-catalog-ids	e0e8b460c609b9999ccd0df9ad14294613eed939	2026-08-11 14:42:36.552062
49	buckets-objects-grants-postgres	072b1195d0d5a2f888af6b2302a1938dd94b8b3d	2026-08-11 14:42:36.573285
50	search-v2-optimised	6323ac4f850aa14e7387eb32102869578b5bd478	2026-08-11 14:42:36.580854
51	index-backward-compatible-search	2ee395d433f76e38bcd3856debaf6e0e5b674011	2026-08-11 14:42:36.654052
52	drop-not-used-indexes-and-functions	5cc44c8696749ac11dd0dc37f2a3802075f3a171	2026-08-11 14:42:36.656784
53	drop-index-lower-name	d0cb18777d9e2a98ebe0bc5cc7a42e57ebe41854	2026-08-11 14:42:36.667844
54	drop-index-object-level	6289e048b1472da17c31a7eba1ded625a6457e67	2026-08-11 14:42:36.671555
55	prevent-direct-deletes	262a4798d5e0f2e7c8970232e03ce8be695d5819	2026-08-11 14:42:36.673832
56	fix-optimized-search-function	b823ed1e418101032fa01374edc9a436e54e3ed4	2026-08-11 14:42:36.680935
57	s3-multipart-uploads-metadata	f127886e00d1b374fadbc7c6b31e09336aad5287	2026-08-11 14:42:36.689637
58	operation-ergonomics	00ca5d483b3fe0d522133d9002ccc5df98365120	2026-08-11 14:42:36.696539
59	drop-unused-functions	38456f13e39691c2bbb4b5151d0d1cdbabd4a8c4	2026-08-11 14:42:36.703937
60	optimize-existing-functions-again	db35e1c91a9201e59f4fef8d972c2f277d68b157	2026-08-11 14:42:36.710816
61	mark-filename-immutable	fe0096517ae9d60aaec1d110172ba9036dc66bb7	2026-08-11 14:42:36.718318
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads (id, in_progress_size, upload_signature, bucket_id, key, version, owner_id, created_at, user_metadata, metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads_parts (id, upload_id, size, part_number, bucket_id, key, etag, owner_id, version, created_at) FROM stdin;
\.


--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.vector_indexes (id, name, bucket_id, data_type, dimension, distance_metric, metadata_configuration, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
--

COPY vault.secrets (id, name, description, secret, key_id, nonce, created_at, updated_at) FROM stdin;
\.


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: -
--

SELECT pg_catalog.setval('auth.refresh_tokens_id_seq', 1, false);


--
-- Name: lifecycle_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lifecycle_statuses_id_seq', 3, true);


--
-- Name: subscription_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: -
--

SELECT pg_catalog.setval('realtime.subscription_id_seq', 1, false);


--
-- PostgreSQL database dump complete
--

\unrestrict Dt1ccbY4l0A4trNO4gU7lplT1JhywqfKkadSmu7afi5o494PBO1NkphBfjag1sp

