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

COPY public.relationship_types (id, code, name, description, is_directional, inverse_type_id, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	CONTAINS_INGREDIENT	Contains Ingredient	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
c816beeb-b723-40a1-9220-910125714e86	MAY_CONTAIN_INGREDIENT	May Contain Ingredient	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
18fa6ec8-afd8-40b2-b468-adc78bd6be12	CONTAINS_ALLERGEN	Contains Allergen	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
eb53c526-c4e5-47d0-827e-482d02a45b37	MAY_CONTAIN_ALLERGEN	May Contain Allergen	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
7489a8be-be9a-4f22-b472-96f7140295be	PRIMARY_BARCODE	Primary Barcode	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
e7a52d95-a5d2-471f-b106-926375279fa4	PACK_SIZE_VARIANT	Pack Size Variant	\N	t	\N	0	1	1	2026-08-11 00:13:03.870976+00	2026-08-11 00:13:03.870976+00	\N
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
-- Data for Name: verification_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.verification_statuses (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
18ca5db5-32b8-4662-ac0d-be0b15cf0ba1	UNVERIFIED	Unverified	\N	0	1	1	2026-08-11 00:13:05.238317+00	2026-08-11 00:13:05.238317+00	\N
05408d93-519d-4e19-96d4-3a18bd1e85de	PENDING	Pending Verification	\N	0	1	1	2026-08-11 00:13:05.238317+00	2026-08-11 00:13:05.238317+00	\N
ed354cfc-f915-4805-842d-f035d8aacec5	VERIFIED	Verified	\N	0	1	1	2026-08-11 00:13:05.238317+00	2026-08-11 00:13:05.238317+00	\N
bcbb0479-e1eb-4177-bc2d-7d3fe2aba8b1	REJECTED	Rejected	\N	0	1	1	2026-08-11 00:13:05.238317+00	2026-08-11 00:13:05.238317+00	\N
\.


--
-- Name: lifecycle_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lifecycle_statuses_id_seq', 3, true);


--
-- PostgreSQL database dump complete
--

\unrestrict ec4KFvIZMrTOLkzNPfKB0ikYa0vYdSyosSvtaR0gkVhwZlhx8Y4I8Zj7rJtjFn6

