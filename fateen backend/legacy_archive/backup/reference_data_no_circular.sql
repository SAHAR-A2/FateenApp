--
-- PostgreSQL database dump
--

\restrict ec4KFvIZMrTOLkzNPfKB0ikYa0vYdSyosSvtaR0gkVhwZlhx8Y4I8Zj7rJtjFn6

-- Dumped from database version 17.10 (Debian 17.10-1.pgdg13+1)
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
-- Data for Name: lifecycle_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lifecycle_statuses (id, code, name, description, display_order, version_number, created_at, updated_at, deleted_at) FROM stdin;
1	ACTIVE	Active	Reference row is in service and eligible for use.	1	1	2026-08-10 11:12:51.728364+00	2026-08-10 11:12:51.728364+00	\N
2	DEPRECATED	Deprecated	No longer recommended; kept for history and referential integrity.	2	1	2026-08-10 11:12:51.728364+00	2026-08-10 11:12:51.728364+00	\N
3	ARCHIVED	Archived	Retired from use; preserved for audit and history.	3	1	2026-08-10 11:12:51.728364+00	2026-08-10 11:12:51.728364+00	\N
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
-- Data for Name: evidence_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.evidence_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
c24d31c8-beda-4579-a81c-9ca44d430170	LABEL	Product Label	\N	0	1	1	2026-08-11 00:13:04.502262+00	2026-08-11 00:13:04.502262+00	\N
4748581e-f31c-4cbb-8ff7-58d898618f91	MANUFACTURER	Manufacturer	\N	0	1	1	2026-08-11 00:13:04.502262+00	2026-08-11 00:13:04.502262+00	\N
357c53ca-be84-4972-b455-fb4ba5bf7db2	OFFICIAL_SOURCE	Official Source	\N	0	1	1	2026-08-11 00:13:04.502262+00	2026-08-11 00:13:04.502262+00	\N
8b8071bd-53f4-4896-9587-d0114af571c3	DATABASE	Database Record	\N	0	1	1	2026-08-11 00:13:04.502262+00	2026-08-11 00:13:04.502262+00	\N
\.


--
-- Data for Name: languages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.languages (id, code, name, native_name, is_rtl, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
c43b9ba9-e823-42b3-b031-2a9ec3ece457	en	English	English	f	1	1	2026-08-11 00:28:03.944019+00	2026-08-11 00:28:03.944019+00	\N
4b80bc8d-396c-406c-b479-2c4274fed94a	ar	Arabic	العربية	f	1	1	2026-08-11 00:28:03.944019+00	2026-08-11 00:28:03.944019+00	\N
\.


--
-- Data for Name: relationship_types; Type: TABLE DATA; Schema: public; Owner: -
--

