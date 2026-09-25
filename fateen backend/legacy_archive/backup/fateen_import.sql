--
-- PostgreSQL database dump
--

\restrict vePCSWivNeBRguDmNJ1e2QuELeQicUm5aCOuifizYxdfDh7noej5zmIhrRcfHsm

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
-- Data for Name: countries; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: source_priorities; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: data_sources; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: allergens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allergens (id, allergen_type_id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
5c302be6-3afe-4ed7-919c-c308158bc54e	b4ef879c-7d2c-443b-9435-055c9a442fb7	MILK	Milk	Milk and milk-derived proteins	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
1ead5274-48ad-4c67-bde1-73fad80eb19e	b4ef879c-7d2c-443b-9435-055c9a442fb7	EGG	Egg	Egg and egg-derived proteins	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
f62d44e1-1646-450a-b8ee-2a6adf6cd7cd	b4ef879c-7d2c-443b-9435-055c9a442fb7	PEANUT	Peanut	Peanut and peanut-derived ingredients	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
796f3f70-b86a-417d-8f17-9f928882d824	b4ef879c-7d2c-443b-9435-055c9a442fb7	TREE_NUTS	Tree Nuts	Tree nuts and derived ingredients	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
2cfdcf5e-487a-4c61-bdbd-e5acbac726d0	b4ef879c-7d2c-443b-9435-055c9a442fb7	WHEAT	Wheat	Wheat and wheat-derived ingredients	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
4bc260bc-d95a-4a8b-84c1-c7c6cdbdfced	b4ef879c-7d2c-443b-9435-055c9a442fb7	SOY	Soy	Soybean and soy-derived ingredients	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
6d0112a9-81c0-4184-b317-f24c886f9ae5	b4ef879c-7d2c-443b-9435-055c9a442fb7	SESAME	Sesame	Sesame and sesame-derived ingredients	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
e3b64b8a-7dbb-42d5-8788-c759084e49a0	b4ef879c-7d2c-443b-9435-055c9a442fb7	FISH	Fish	Fish and fish-derived ingredients	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
bd366d6c-718f-4ee4-ac11-1b2b0dbaa8c2	b4ef879c-7d2c-443b-9435-055c9a442fb7	SHELLFISH	Shellfish	Crustaceans and shellfish	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
d958c1ac-c2c8-47d2-80de-f001c7b44705	b4ef879c-7d2c-443b-9435-055c9a442fb7	MUSTARD	Mustard	Mustard and mustard-derived ingredients	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N
\.


--
-- Data for Name: allergen_translations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allergen_translations (id, allergen_id, language_id, name, short_name, display_name, search_name, description, translation_status, version_number, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: role_types; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: audit_context; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: change_sets; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: allergens_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allergens_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, allergen_type_id, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
8a3edd58-c78f-4e71-8964-2497c756bb2b	5c302be6-3afe-4ed7-919c-c308158bc54e	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	MILK	Milk	Milk and milk-derived proteins	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	293e3577c1c70aeefde7579869d4e8940ba5bf53174812396fb1c46aae8798db	d60628ef0b80fd7ece8afdf176b4b3b7ae2c44f0da95d4bc451b1329ba02a295	draft
ea3d99f6-ead2-49ed-b8e6-efbde72f2e61	1ead5274-48ad-4c67-bde1-73fad80eb19e	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	EGG	Egg	Egg and egg-derived proteins	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	5b166d6a35c37d49f6c2bf20f9290661be87b2e3df9a55606abf264b4c6d5bee	dbb6666df3e2a2c6594b6eb2e77141c36d04cfaf8e4ddb464dcbbefcf424d0e8	draft
52d730c0-743e-4bc2-b79f-cbbf4df255b1	f62d44e1-1646-450a-b8ee-2a6adf6cd7cd	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	PEANUT	Peanut	Peanut and peanut-derived ingredients	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	b6b4f0a5737d9d7b5377d96cf6df8744340c29c82d334bb8cc595f9f23083ce6	2aca87ddc7c53f5c174c04f244ba8f3f60acdb71a7d0a07d161c974605ecfab9	draft
99694312-bd68-4655-837d-ea51ddb159d8	796f3f70-b86a-417d-8f17-9f928882d824	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	TREE_NUTS	Tree Nuts	Tree nuts and derived ingredients	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	887d71528aaf247cd6f5a57a8e9ad1f912e036cbc14b18bf18ebdbc90124c8ad	ab44c22f76d6bd7eb2bcb104b3ee54bb37c5eb1e27044fae400a0da4ce0a8f1f	draft
ebda6f03-7a46-4170-a1b8-74a1196f8170	2cfdcf5e-487a-4c61-bdbd-e5acbac726d0	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	WHEAT	Wheat	Wheat and wheat-derived ingredients	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	5b97b5c773779a81d0b196813f827e37b32f19e73c1173afb07bf6f730f463f4	99c8bf5eb09b4fcb231a712dcbdf5df601adb5cbd91016e074992c1b180f4a13	draft
f36ee98e-cd24-4dc5-8316-75b812dc9cc4	4bc260bc-d95a-4a8b-84c1-c7c6cdbdfced	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	SOY	Soy	Soybean and soy-derived ingredients	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	6b125ae5bd7a94f39248558828b855809775b9f33dad5d99638369d6712ee4b8	92eb388633898dc1d9454c18e5f58bd45c1c56881b7e9093877162b6c37b7e2a	draft
43c7b7f4-2aee-492f-b8ce-931f0eadf47e	6d0112a9-81c0-4184-b317-f24c886f9ae5	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	SESAME	Sesame	Sesame and sesame-derived ingredients	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	1618e14d047f0711839669aa69379538da2de2fd1e19f005df7571466313dfc6	08b5b90b52f8493f44b4277841721dad6b2ac20e7e98d1d08be19cbb08317929	draft
645de3ba-a3fb-4d28-978f-080337ef6e3d	e3b64b8a-7dbb-42d5-8788-c759084e49a0	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	FISH	Fish	Fish and fish-derived ingredients	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	bcfa1f2fd8da634aabb9053c3e58d744d0da4e7c3137fafa739fb0f69281a1cc	0c88d15633494e3036dcdf7828ec30ce73eddb598908ec379c254273a0da9e5e	draft
0235a1f6-c6d0-46da-a7e6-d02d7ac42abf	bd366d6c-718f-4ee4-ac11-1b2b0dbaa8c2	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	SHELLFISH	Shellfish	Crustaceans and shellfish	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	708d59d0418d4a6623102c4aca432a33fc67a1e005e50b3f8cf1f997fa12bcd4	baebcf51f46beb2eeb5ddf91e6fbee472fd9011c95455fb12c93a38585889eaf	draft
67ad95ed-b9a4-4056-886d-bb25594bb89e	d958c1ac-c2c8-47d2-80de-f001c7b44705	1	\N	\N	created	\N	\N	\N	\N	1.0	b4ef879c-7d2c-443b-9435-055c9a442fb7	MUSTARD	Mustard	Mustard and mustard-derived ingredients	1	\N	\N	\N	\N	2026-08-11 00:17:46.400147+00	2026-08-11 00:17:46.400147+00	\N	\N	b857d2ce5628b36776e5a60c4fedff6fe3f43431250d07e6e0430071cb52ed36	3f72d7cd6890f9890b0462707263f89b8bf813cfef622147700b54fa4e8f596d	draft
\.


--
-- Data for Name: audit_event_types; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: audit_events; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: barcodes; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: barcodes_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: brand_search_index; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.companies (id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
8ff0eaab-6877-4d36-9c83-412a88d0a577	GENERIC_FOOD_CO	Generic Food Company	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:29:11.151283+00	2026-08-11 00:29:11.151283+00	\N
e54d9b60-aa2c-49ea-b9af-01b31fec629d	FATEEN_TEST_CO	Fateen Test Company	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:29:11.151283+00	2026-08-11 00:29:11.151283+00	\N
3f620960-52e2-40f9-a33d-21d3450c7adf	NESTLE	Nestle	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N
e430d47e-372a-409c-b89c-cd8d61c56748	UNILEVER	Unilever	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N
51fea794-41df-405f-87e6-eee26cdd075b	PEPSICO	PepsiCo	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N
1375ba99-37e4-4ae1-ad04-3d31e1149a7e	MONDELEZ	Mondelez International	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N
b4c0c793-ce66-4d49-a887-445032ef46bc	DANONE	Danone	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N
ba19618f-2a03-4c54-9a56-df5c348b1624	MARS	Mars	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N
23d86625-13ba-455e-941f-973baab652ec	KRAFT_HEINZ	Kraft Heinz	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N
85bebf98-420b-433e-8745-f66aef1b6ee8	GENERAL_MILLS	General Mills	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N
\.


--
-- Data for Name: brands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.brands (id, company_id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
0ff81924-4e05-46e2-8c01-075cabded0b7	8ff0eaab-6877-4d36-9c83-412a88d0a577	GENERIC_BRAND	Generic Food Brand	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:29:11.798863+00	2026-08-11 00:29:11.798863+00	\N
a03497f8-562e-4b20-a98c-8ec497c5bccd	e54d9b60-aa2c-49ea-b9af-01b31fec629d	FATEEN_TEST	Fateen Test Brand	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:29:11.798863+00	2026-08-11 00:29:11.798863+00	\N
feec1927-2905-470e-86bd-47f2673dadb8	3f620960-52e2-40f9-a33d-21d3450c7adf	MAGGI	Maggi	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
b9a7338b-4432-4292-85ea-6d3a80e193ff	3f620960-52e2-40f9-a33d-21d3450c7adf	KITKAT	KitKat	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
e98ff5f4-5a2f-4b38-93b9-37d78707f98a	3f620960-52e2-40f9-a33d-21d3450c7adf	NESCAFE	Nescafe	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
aa0999cd-c851-4d26-af94-adc9a2186038	e430d47e-372a-409c-b89c-cd8d61c56748	DOVE	Dove	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
84926a6b-f834-48cb-b8b8-4cbe8cdda5e2	51fea794-41df-405f-87e6-eee26cdd075b	LAYS	Lays	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
ef1810d6-484a-40f1-adc2-a3bbeb5bea8a	51fea794-41df-405f-87e6-eee26cdd075b	PEPSI	Pepsi	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
c0c7d43a-fdd0-4dc3-99d8-fa2fb488337f	1375ba99-37e4-4ae1-ad04-3d31e1149a7e	OREO	Oreo	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
08d101d9-3b50-4a9d-a44b-bcfbb7d660cf	b4c0c793-ce66-4d49-a887-445032ef46bc	ACTIVIA	Activia	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
c4f51fa8-e37d-4198-b211-f7dc81119b4f	b4c0c793-ce66-4d49-a887-445032ef46bc	DANONE	Danone	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
af458dbe-a774-42b0-8a0c-08faaff9d8d2	ba19618f-2a03-4c54-9a56-df5c348b1624	KINDER	Kinder	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N
0d92198c-de93-4b67-ba62-bda3bd45f1cd	3f620960-52e2-40f9-a33d-21d3450c7adf	TEST_TRIGGER_BRAND	Test Trigger Brand	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:39:09.624692+00	2026-08-11 00:39:09.624692+00	\N
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
21218e9b-1bae-4d8e-ad0e-9cfd08a885a1	0ff81924-4e05-46e2-8c01-075cabded0b7	1	\N	\N	created	\N	\N	\N	\N	0.5	8ff0eaab-6877-4d36-9c83-412a88d0a577	GENERIC_BRAND	Generic Food Brand	\N	1	\N	\N	\N	\N	2026-08-11 00:29:11.798863+00	2026-08-11 00:29:11.798863+00	\N	\N	daf5e6c216b8ed40cab632e865e5d0413220da76c5339bb114955372a0530b29	a786717cb0ed1c8c6de0c3f54cdf00aa34253398f4ce1418c4f9daffa4f8d8ae	draft
53b2ace7-9950-48ba-8dec-5db21e83956c	a03497f8-562e-4b20-a98c-8ec497c5bccd	1	\N	\N	created	\N	\N	\N	\N	0.5	e54d9b60-aa2c-49ea-b9af-01b31fec629d	FATEEN_TEST	Fateen Test Brand	\N	1	\N	\N	\N	\N	2026-08-11 00:29:11.798863+00	2026-08-11 00:29:11.798863+00	\N	\N	a5508cc7fc51aa9b888113923dab81a4dd8515fb689f45c2b4fc8a9a43e7008b	343686c6417202eba5c8067031ca1e299a73fc95632e2bc3525d72bf8a7fea93	draft
611aa17f-f082-4d40-81b0-23d54036edc7	feec1927-2905-470e-86bd-47f2673dadb8	1	\N	\N	created	\N	\N	\N	\N	0.5	3f620960-52e2-40f9-a33d-21d3450c7adf	MAGGI	Maggi	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	99a0a9c41a9cb0f48b2440f28acf481e4b15549990e5c19544c42affc494832c	7dc8dd6b05a2eef5404c401295acd9f8304052620fe381995cf8b2712a6f5d8e	draft
a41be16a-b51c-42ef-b8d3-fa18bf29f992	b9a7338b-4432-4292-85ea-6d3a80e193ff	1	\N	\N	created	\N	\N	\N	\N	0.5	3f620960-52e2-40f9-a33d-21d3450c7adf	KITKAT	KitKat	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	d3d2cf7623711d570b5fb819c89d47b354cdec0f9944f0a4ec8c8979ca80099d	60525988f6518c99a3f282f51ee4dc0a88871c4f1c01e0eb247afc42036eee8c	draft
18c74a1f-03ef-4363-9fb2-39c4ef1f079e	e98ff5f4-5a2f-4b38-93b9-37d78707f98a	1	\N	\N	created	\N	\N	\N	\N	0.5	3f620960-52e2-40f9-a33d-21d3450c7adf	NESCAFE	Nescafe	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	6fd5b57af36eeeafbf78a76d9214dc3c5f4403b00a158577301f109a3bb9b05e	79fe475f4ae3995d06b80a25b55d2c88d592720894211fdf2a28cf1ba2de8359	draft
f3ad9b34-4507-4ed2-9f94-ebfa817f8b68	aa0999cd-c851-4d26-af94-adc9a2186038	1	\N	\N	created	\N	\N	\N	\N	0.5	e430d47e-372a-409c-b89c-cd8d61c56748	DOVE	Dove	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	f27098615ea236025cfb934c7f9373a475d13bb975e5575f5fd598be3adbd981	332a0d7aa901a4f28983041c5951ec573f2fdf1603488efb29e2b4a4a65b2aba	draft
43a016cc-7086-4be9-9538-55272e41bdff	84926a6b-f834-48cb-b8b8-4cbe8cdda5e2	1	\N	\N	created	\N	\N	\N	\N	0.5	51fea794-41df-405f-87e6-eee26cdd075b	LAYS	Lays	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	81c02dc0ddde68e4ece44ac14c6ed5bd0573a48472a9764173ecdbac54bf4ddb	0f1d294518ec72c76f9de5138d1315d974aafbeefdb77ba1925de90584bdddd3	draft
c02bc38a-8671-4201-859a-eef53663ad9d	ef1810d6-484a-40f1-adc2-a3bbeb5bea8a	1	\N	\N	created	\N	\N	\N	\N	0.5	51fea794-41df-405f-87e6-eee26cdd075b	PEPSI	Pepsi	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	12912b0b5397b04b66fa8b919d94760b875c9cd507a549546b390e4cd61fa845	dc712dc121804b187d70b81b98ebbdf404b76944c2fd6f718904033849ee9f93	draft
16286585-a760-4bfd-91b4-080dbf2584e2	c0c7d43a-fdd0-4dc3-99d8-fa2fb488337f	1	\N	\N	created	\N	\N	\N	\N	0.5	1375ba99-37e4-4ae1-ad04-3d31e1149a7e	OREO	Oreo	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	14316400ef94928823b482f173460692a60831bb564d356ae383d8ab0d0b1bb0	b338de73dc8a1ab13616dac200ad76c6ceab9a15ea59ace01c1f7f1f88a983fa	draft
01713a18-9477-4754-9d8a-3dcf077675e2	08d101d9-3b50-4a9d-a44b-bcfbb7d660cf	1	\N	\N	created	\N	\N	\N	\N	0.5	b4c0c793-ce66-4d49-a887-445032ef46bc	ACTIVIA	Activia	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	cbb2b4cd2762ec1b0b62868b00675ee69d47aff53da272578af5cf55faac10fa	c6478b2322e2adc89b2091a1e85f07de41f2f2301181249b3c94a849fee4c430	draft
46acb181-50c1-4a84-867b-e76d7f46458b	c4f51fa8-e37d-4198-b211-f7dc81119b4f	1	\N	\N	created	\N	\N	\N	\N	0.5	b4c0c793-ce66-4d49-a887-445032ef46bc	DANONE	Danone	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	a7df213a35cb013e602d5417bd4a91fa2019ed362725d838de3dcd6ca2cd90fc	fba3fb54a88ae2f1ebc01c8ab58854e5334cca357215865272b7ceafef7593c0	draft
cc303136-f68b-4c11-b687-68d4b44d133d	af458dbe-a774-42b0-8a0c-08faaff9d8d2	1	\N	\N	created	\N	\N	\N	\N	0.5	ba19618f-2a03-4c54-9a56-df5c348b1624	KINDER	Kinder	\N	1	\N	\N	\N	\N	2026-08-11 00:37:23.412284+00	2026-08-11 00:37:23.412284+00	\N	\N	f9b482481eb5296654202cf417f7e082b18846e6e9747b0a3c705b51657d6ef0	1ff874626d68c6126255c55674f3e392ae93ab228606131b128d6c78699994b9	draft
11415be4-62d9-4a2d-889d-86156d6d6eec	0d92198c-de93-4b67-ba62-bda3bd45f1cd	1	\N	\N	created	\N	\N	\N	\N	0.5	3f620960-52e2-40f9-a33d-21d3450c7adf	TEST_TRIGGER_BRAND	Test Trigger Brand	\N	1	\N	\N	\N	\N	2026-08-11 00:39:09.624692+00	2026-08-11 00:39:09.624692+00	\N	\N	d4bbab2659a7bef33861cfab3036c90c28f5fbb946c61a906ccf2dc61145598d	156587d8cbecb3225ecc5029af3592e72e633603906506acaedfaaeaca9e9722	draft
\.


--
-- Data for Name: companies_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.companies_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
b638ad95-9241-462e-bc0d-b875683255b8	8ff0eaab-6877-4d36-9c83-412a88d0a577	1	\N	\N	created	\N	\N	\N	\N	0.5	GENERIC_FOOD_CO	Generic Food Company	\N	1	\N	\N	\N	\N	2026-08-11 00:29:11.151283+00	2026-08-11 00:29:11.151283+00	\N	\N	c4c0547a92b96ead3033704d3bf12f0e385f98e90a4c5484c9f29c4efc9980c0	0a2bfb7e99eae24e486e27bc75cccf9d1c9ddcf90a8751b9ed7cbf784e4ed398	draft
be5a575d-af30-4f9c-92c4-eeb4abf73ba5	e54d9b60-aa2c-49ea-b9af-01b31fec629d	1	\N	\N	created	\N	\N	\N	\N	0.5	FATEEN_TEST_CO	Fateen Test Company	\N	1	\N	\N	\N	\N	2026-08-11 00:29:11.151283+00	2026-08-11 00:29:11.151283+00	\N	\N	ea545195ad907f9a240e862aa733aa9d2fac37110d862bf0e205cedf66112b56	314050191f32c73a2cbcd5a584f43db0a15fe6602aaa78b595ee7667c1023195	draft
9b4015af-ff8d-4b9e-b04a-26b5523a0394	3f620960-52e2-40f9-a33d-21d3450c7adf	1	\N	\N	created	\N	\N	\N	\N	0.5	NESTLE	Nestle	\N	1	\N	\N	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N	\N	dab1891738f355a866138c3fa5e59e149eb5a3136a33208b5e2c14962220183e	a9039477f921570b730426d3903268d9ced09d5fddc804ac13ff20b06520c8ee	draft
de1c7d20-31de-4dae-b127-2dd4d8745fcc	e430d47e-372a-409c-b89c-cd8d61c56748	1	\N	\N	created	\N	\N	\N	\N	0.5	UNILEVER	Unilever	\N	1	\N	\N	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N	\N	f895fe0807a583a409c0ef23a8925b659cd85af756c8e8c1859a627d47df354f	37313e081fd031bacb92ef79ccf78c05408d1ec8383b035caa58c6f74d686cf1	draft
214a8f99-5a84-442e-915f-cbc152d17253	51fea794-41df-405f-87e6-eee26cdd075b	1	\N	\N	created	\N	\N	\N	\N	0.5	PEPSICO	PepsiCo	\N	1	\N	\N	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N	\N	98ecd9fbe748532fbaae4b7af86912060ed5bf61590dcca22783c9cfb9d42f2e	b02cc9385f4386eaad1171ec663ed5835c15aa94c5af96775ff1b481aa30365d	draft
0af20945-3782-439f-bab2-1f9b971ae338	1375ba99-37e4-4ae1-ad04-3d31e1149a7e	1	\N	\N	created	\N	\N	\N	\N	0.5	MONDELEZ	Mondelez International	\N	1	\N	\N	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N	\N	1434241efcd8ccf6cd963e07837515fbd5ec1268ad446522218a2d1856ce89ee	8d714496d8b74869d5376ed6722baae1ad35a1905c2edc61286b7a94257f2572	draft
d2953bc0-35cf-4584-928b-978726f650b7	b4c0c793-ce66-4d49-a887-445032ef46bc	1	\N	\N	created	\N	\N	\N	\N	0.5	DANONE	Danone	\N	1	\N	\N	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N	\N	f14f3a76251a6e828910539375be7a377ed12f9aea7e90285df054e27e2c47a4	4602f5f1d81cea81ac6428bf7874201603897088c01c8148edbdf89b25d405ac	draft
e1430849-8ec5-4d8b-9248-0706f9271b06	ba19618f-2a03-4c54-9a56-df5c348b1624	1	\N	\N	created	\N	\N	\N	\N	0.5	MARS	Mars	\N	1	\N	\N	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N	\N	61b0288dd7dc3d35aed919991d0f01655bf11bba078e93ab380b4a2bf2c18702	6582bb104cde92609efe6ea69236948f208264cf58ddecff293277d4fcf24513	draft
af0c2471-9802-49f6-893d-c5393a773ce0	23d86625-13ba-455e-941f-973baab652ec	1	\N	\N	created	\N	\N	\N	\N	0.5	KRAFT_HEINZ	Kraft Heinz	\N	1	\N	\N	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N	\N	ad812ff5707887a8916056f6188516df5589f7346c3dae9f7d85f919b2f1a439	54f1dc6e3de2022df6e2b4ae192b0ada5de3589492afc8b547c3a563b6f7876d	draft
1a3cccf1-cfc6-4ede-8a78-aad21f296e3d	85bebf98-420b-433e-8745-f66aef1b6ee8	1	\N	\N	created	\N	\N	\N	\N	0.5	GENERAL_MILLS	General Mills	\N	1	\N	\N	\N	\N	2026-08-11 00:31:18.814809+00	2026-08-11 00:31:18.814809+00	\N	\N	0585f54ff66bae707a4d22b186071c67dbbdb7fc1e6f6e2063bf5445ced29cd6	49fa2dec621d86777faf929e56b6936475389dd3173a32edaee7b1efdc81041b	draft
\.


--
-- Data for Name: company_search_index; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: company_translations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: entity_relationships; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: entity_versions; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: health_flags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.health_flags (id, health_flag_type_id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
eb5af6be-c413-4347-8a54-f110ae667d8d	7ae7c564-719a-4320-a950-c2ec04c5cb02	DIABETES	Diabetes	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:06.120948+00	2026-08-11 00:28:06.120948+00	\N
60db7be0-152e-4e70-800b-6087f4723744	7ae7c564-719a-4320-a950-c2ec04c5cb02	HIGH_BLOOD_PRESSURE	High Blood Pressure	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:06.120948+00	2026-08-11 00:28:06.120948+00	\N
a872207b-ba89-4d19-a992-0d05d36288f1	c40db76f-62b3-4d19-a813-603112731cef	CELIAC	Celiac Disease	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:06.562659+00	2026-08-11 00:28:06.562659+00	\N
c7b229b1-67ea-4e61-bbc7-03c34af20ec3	c40db76f-62b3-4d19-a813-603112731cef	LACTOSE_INTOLERANCE	Lactose Intolerance	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:06.562659+00	2026-08-11 00:28:06.562659+00	\N
11de7600-e511-43c7-9b0a-e04681b94f81	c40db76f-62b3-4d19-a813-603112731cef	GLUTEN_INTOLERANCE	Gluten Intolerance	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:06.562659+00	2026-08-11 00:28:06.562659+00	\N
0f0c49af-7397-4fde-b22b-f3cb60120ecc	f8e96b2d-fbbb-4e78-bca9-1c8805dbf4ae	VEGAN	Vegan	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:06.960877+00	2026-08-11 00:28:06.960877+00	\N
e7121381-6737-4cc5-85f4-ec2a2143129b	f8e96b2d-fbbb-4e78-bca9-1c8805dbf4ae	VEGETARIAN	Vegetarian	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:06.960877+00	2026-08-11 00:28:06.960877+00	\N
081721ed-28f0-43cd-a6fe-3353fec6ba27	62881f5c-4da1-4cc6-a0aa-69ec6f15a300	LOW_SODIUM	Low Sodium	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:07.350953+00	2026-08-11 00:28:07.350953+00	\N
9e024bbd-4ae8-4374-9552-3bb2ca712fa4	62881f5c-4da1-4cc6-a0aa-69ec6f15a300	LOW_SUGAR	Low Sugar	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:07.350953+00	2026-08-11 00:28:07.350953+00	\N
9f9e3de6-7869-40ad-9ff8-da7f585a78ce	62881f5c-4da1-4cc6-a0aa-69ec6f15a300	LOW_FAT	Low Fat	\N	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:28:07.350953+00	2026-08-11 00:28:07.350953+00	\N
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
8d73ab61-a7b4-4123-94c0-715bfdbb71d7	eb5af6be-c413-4347-8a54-f110ae667d8d	1	\N	\N	created	\N	\N	\N	\N	1.0	7ae7c564-719a-4320-a950-c2ec04c5cb02	DIABETES	Diabetes	\N	1	\N	\N	\N	\N	2026-08-11 00:28:06.120948+00	2026-08-11 00:28:06.120948+00	\N	\N	32c79a89b06fce692051b627eb0830ede2e23b6d6e44ea29101ab7ce988a2a43	3b3a9e18151f5f1e6049df8e8785a14f125542258cdd27942823e821a045e795	draft
6e65db68-98fc-48f4-a170-914c1b1f582f	60db7be0-152e-4e70-800b-6087f4723744	1	\N	\N	created	\N	\N	\N	\N	1.0	7ae7c564-719a-4320-a950-c2ec04c5cb02	HIGH_BLOOD_PRESSURE	High Blood Pressure	\N	1	\N	\N	\N	\N	2026-08-11 00:28:06.120948+00	2026-08-11 00:28:06.120948+00	\N	\N	adecfe1b2e91e303ef997257444a2cea0a51a1a4d298c2fa32e026a431f4842b	9b1633e92975247156a4aefa058f738eb72bec0f3a0f8f2557f681f9ca8e413b	draft
18ca5bbb-b2b9-4171-a1d0-48b4400d1b98	a872207b-ba89-4d19-a992-0d05d36288f1	1	\N	\N	created	\N	\N	\N	\N	1.0	c40db76f-62b3-4d19-a813-603112731cef	CELIAC	Celiac Disease	\N	1	\N	\N	\N	\N	2026-08-11 00:28:06.562659+00	2026-08-11 00:28:06.562659+00	\N	\N	15160951d6c777d7b73cd2f695487cb649d1456744b615eecf9ab3f01daa522f	729969dece69fdde543f6bf61f3c3e3b1e266ae98ad3a7bd4489b05566af74f0	draft
bc55019c-b80a-4725-b92e-4858968dda15	c7b229b1-67ea-4e61-bbc7-03c34af20ec3	1	\N	\N	created	\N	\N	\N	\N	1.0	c40db76f-62b3-4d19-a813-603112731cef	LACTOSE_INTOLERANCE	Lactose Intolerance	\N	1	\N	\N	\N	\N	2026-08-11 00:28:06.562659+00	2026-08-11 00:28:06.562659+00	\N	\N	e0fc451b69f1d4ef22c2f6fdaef753c0f29db4feefb6a638ab0386f1217cce8c	cff9931efed269dc85790817901982ff5c0366beec49d619acce279842bc6265	draft
0ce05af4-309f-45d9-9133-08334b65ecf7	11de7600-e511-43c7-9b0a-e04681b94f81	1	\N	\N	created	\N	\N	\N	\N	1.0	c40db76f-62b3-4d19-a813-603112731cef	GLUTEN_INTOLERANCE	Gluten Intolerance	\N	1	\N	\N	\N	\N	2026-08-11 00:28:06.562659+00	2026-08-11 00:28:06.562659+00	\N	\N	e6340b2d4fd52aebe23fe52ed66b2378364f085dc43b5a397ce052e0bfaa2810	a9d3ab1c005554377bf7a1fda3f2533c598a71383d2d2cb2ff4aab6942d825e5	draft
98845dca-9e6b-4f7c-a47d-5c9d5e1e51d0	0f0c49af-7397-4fde-b22b-f3cb60120ecc	1	\N	\N	created	\N	\N	\N	\N	1.0	f8e96b2d-fbbb-4e78-bca9-1c8805dbf4ae	VEGAN	Vegan	\N	1	\N	\N	\N	\N	2026-08-11 00:28:06.960877+00	2026-08-11 00:28:06.960877+00	\N	\N	e8d3daffeb173e03feafec9e127b1a9ecd2f1862a6b447ea6ea40242ce90ea4c	3032235ae000e4666992b307248fffffc9654e4bc5e5390d7b837be5be9c7c49	draft
cc15e672-d95a-4682-86f1-96b09e7c09fd	e7121381-6737-4cc5-85f4-ec2a2143129b	1	\N	\N	created	\N	\N	\N	\N	1.0	f8e96b2d-fbbb-4e78-bca9-1c8805dbf4ae	VEGETARIAN	Vegetarian	\N	1	\N	\N	\N	\N	2026-08-11 00:28:06.960877+00	2026-08-11 00:28:06.960877+00	\N	\N	6195980f7f2b7f59dc03b68ad1479d3d49ccfe327c7d573e854008a31647dbcc	13d0d83a00b1a316e726184c49180ef61ca053b44900879475a1011ed52462b8	draft
5626cdf1-d320-4bc1-a081-6fd0b9d31bfb	081721ed-28f0-43cd-a6fe-3353fec6ba27	1	\N	\N	created	\N	\N	\N	\N	1.0	62881f5c-4da1-4cc6-a0aa-69ec6f15a300	LOW_SODIUM	Low Sodium	\N	1	\N	\N	\N	\N	2026-08-11 00:28:07.350953+00	2026-08-11 00:28:07.350953+00	\N	\N	0ac16f0ffa338aca2c06db16bbe14f5617fbb33efaef5d29e6a6be6c0039d026	351e1ba943711eaacf90d091140b22da253d551505bcc91a3d15ef318e2dd7ce	draft
86562c55-a509-435c-be73-7df2cd913cd9	9e024bbd-4ae8-4374-9552-3bb2ca712fa4	1	\N	\N	created	\N	\N	\N	\N	1.0	62881f5c-4da1-4cc6-a0aa-69ec6f15a300	LOW_SUGAR	Low Sugar	\N	1	\N	\N	\N	\N	2026-08-11 00:28:07.350953+00	2026-08-11 00:28:07.350953+00	\N	\N	2ea806d8fc6741ca255002c9396ef0257bc13c3337e89b98ec39dc582626c431	ac6c9231a8bc5807b9e292476b568fbc6f20c68cc9cf00dcec74c63879beb4ff	draft
c46c6acd-b25f-4365-bd7b-55499607e29e	9f9e3de6-7869-40ad-9ff8-da7f585a78ce	1	\N	\N	created	\N	\N	\N	\N	1.0	62881f5c-4da1-4cc6-a0aa-69ec6f15a300	LOW_FAT	Low Fat	\N	1	\N	\N	\N	\N	2026-08-11 00:28:07.350953+00	2026-08-11 00:28:07.350953+00	\N	\N	7f35902cb1cd3bb4b62754e47f748908adb4fc3dc5375f8a9ca95b4f5137ab81	ebbb8f1bdfe1f799d8e20ef64e98eeae7c97d1b18592307f75f78df5d28b14fd	draft
\.


--
-- Data for Name: image_types; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: images; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: images_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: ingredients; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredients (id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
03620dd4-331d-438b-b77e-80647da17601	MILK	Milk	Milk ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
c16e7813-6912-4fe6-9c32-58f7395debbf	WHEY	Whey	Milk-derived whey protein	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
c8631d1a-bbb9-472e-9a69-3135675fef7f	CASEIN	Casein	Milk-derived protein	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
5fabfd34-8dcb-402f-88f0-3aef87155bb1	LACTOSE	Lactose	Milk sugar	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
ffe10640-a09c-435d-845b-47a5316ffc13	EGG	Egg	Egg ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
799ca946-566f-40a1-bab2-4a58876656c9	EGG_WHITE	Egg White	Egg white ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
6941d019-fca8-4e52-982c-86649246b9f1	EGG_YOLK	Egg Yolk	Egg yolk ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
bf178102-a91b-4180-9226-5ccfa8f120a6	PEANUT	Peanut	Peanut ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
23abc89d-f2f9-4c02-8259-483889a86fcc	WHEAT_FLOUR	Wheat Flour	Flour made from wheat	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
06f213a4-6e6f-46b8-8be8-28e6381125e1	WHEAT	Wheat	Wheat ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
64ee34d2-0972-4170-a5f4-838695ad595e	SOY	Soy	Soybean ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
98450c22-a798-42c4-89e6-f7737be16b58	SOY_LECITHIN	Soy Lecithin	Lecithin derived from soybean	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
8f72fe51-a81d-4fe0-97e9-37636b0f3bd2	SESAME	Sesame	Sesame ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
66c8b78e-ed88-4aeb-b856-30b2c413527b	ALMOND	Almond	Tree nut almond	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
cfa55cbb-6646-4d98-8de1-047194fdbce1	CASHEW	Cashew	Tree nut cashew	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
c8e6a39c-564b-422f-b9a4-45b0bc179cb6	WALNUT	Walnut	Tree nut walnut	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
de40f5e6-ee92-4aba-89a1-d413c6dbf37c	FISH	Fish	Fish ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
26f36e96-2965-4927-90ca-a548f22874db	SHRIMP	Shrimp	Crustacean ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
4d49c54b-cf07-4fc0-9171-b15369254083	MUSTARD	Mustard	Mustard ingredient	1	\N	1.0	\N	\N	\N	1	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N
\.


--
-- Data for Name: ingredient_aliases; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredient_aliases (id, ingredient_id, alias, language_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
5f0e5aae-bd2a-48a0-a85b-ed34ab07c012	03620dd4-331d-438b-b77e-80647da17601	Milk Solids	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
fb415dd8-19d8-4427-af75-a7fc7ac78b4b	03620dd4-331d-438b-b77e-80647da17601	Milk	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
8af39b42-8b56-4f2c-b5cf-f1e914e24661	c16e7813-6912-4fe6-9c32-58f7395debbf	Whey Protein	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
4c47cb88-8ed4-44e8-8d95-faa677221fad	c8631d1a-bbb9-472e-9a69-3135675fef7f	Casein	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
f5d928af-26f9-4e40-bc99-b8f4a57210ab	5fabfd34-8dcb-402f-88f0-3aef87155bb1	Milk Sugar	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
e89c9b92-d5ef-462c-adb8-24ad82cefca7	ffe10640-a09c-435d-845b-47a5316ffc13	Eggs	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
fe396cee-622c-4234-a5b3-95eef7e47cc6	799ca946-566f-40a1-bab2-4a58876656c9	Egg White	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
aa310c0d-7a70-4ab3-aed4-7e0d7a353d9b	6941d019-fca8-4e52-982c-86649246b9f1	Egg Yolk	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
b70f7ab9-c6b9-4b40-97fe-ade8345bac12	bf178102-a91b-4180-9226-5ccfa8f120a6	Peanuts	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
f5d6638d-6aff-41a0-ac3f-0fd927902a23	bf178102-a91b-4180-9226-5ccfa8f120a6	Groundnut	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
fe6b8f06-b176-45d4-a03c-8926730cdb36	06f213a4-6e6f-46b8-8be8-28e6381125e1	Wheat Flour	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
ef8fc71d-5195-430f-b5ee-7fd3585a0496	64ee34d2-0972-4170-a5f4-838695ad595e	Soya	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
3ced5b33-e7d9-4a4a-a04d-41508b60017b	98450c22-a798-42c4-89e6-f7737be16b58	Soya Lecithin	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
d291a879-099a-454e-a644-794edc71514b	8f72fe51-a81d-4fe0-97e9-37636b0f3bd2	Sesame Seed	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
5e91c30f-e495-42db-8959-45deb3fb0c32	66c8b78e-ed88-4aeb-b856-30b2c413527b	Almonds	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
a231f0ba-8a5d-427c-b1bb-8213c8765544	cfa55cbb-6646-4d98-8de1-047194fdbce1	Cashews	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
8a40b35a-1caf-4abc-9b4e-8e6c1998cf7b	c8e6a39c-564b-422f-b9a4-45b0bc179cb6	Walnuts	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
317c410e-2fb5-4042-9e24-dd476030fa97	26f36e96-2965-4927-90ca-a548f22874db	Prawn	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
125769ef-927c-4d39-b67c-49d5da782e76	4d49c54b-cf07-4fc0-9171-b15369254083	Mustard	\N	ce47dde0-5a33-4cfd-9751-44bb4f4a58d2	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:21:55.551458+00	2026-08-11 00:21:55.551458+00	\N
\.


--
-- Data for Name: ingredient_allergens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredient_allergens (id, ingredient_id, allergen_id, relationship_type_id, source_id, evidence_type_id, confidence_level, effective_from, effective_to, verified_at, approved_at, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
5777796d-24db-4faf-9c96-1ddb1087c35e	03620dd4-331d-438b-b77e-80647da17601	5c302be6-3afe-4ed7-919c-c308158bc54e	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
b3883dc7-e170-4200-86c6-4afbc69aedfe	c16e7813-6912-4fe6-9c32-58f7395debbf	5c302be6-3afe-4ed7-919c-c308158bc54e	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
6eeacba7-c1f0-4785-8982-94ac7e1b4bc0	c8631d1a-bbb9-472e-9a69-3135675fef7f	5c302be6-3afe-4ed7-919c-c308158bc54e	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
5aba2b77-6142-4996-be57-b6e05bef9e1f	5fabfd34-8dcb-402f-88f0-3aef87155bb1	5c302be6-3afe-4ed7-919c-c308158bc54e	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
a47c3091-3de0-4995-b3d6-8360ea034d95	ffe10640-a09c-435d-845b-47a5316ffc13	1ead5274-48ad-4c67-bde1-73fad80eb19e	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
116099cb-9b0a-437c-8275-92fda973ccd3	799ca946-566f-40a1-bab2-4a58876656c9	1ead5274-48ad-4c67-bde1-73fad80eb19e	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
78cfc911-241b-4096-86d1-8fcaf8098a54	6941d019-fca8-4e52-982c-86649246b9f1	1ead5274-48ad-4c67-bde1-73fad80eb19e	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
f5a30647-591b-4a24-9dcf-8df2f2df5f98	bf178102-a91b-4180-9226-5ccfa8f120a6	f62d44e1-1646-450a-b8ee-2a6adf6cd7cd	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
95b2e3a3-2b56-4077-a5ae-f3d4f7c8c583	23abc89d-f2f9-4c02-8259-483889a86fcc	2cfdcf5e-487a-4c61-bdbd-e5acbac726d0	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
baaa2b86-6078-49fd-8807-4e208ad5c026	06f213a4-6e6f-46b8-8be8-28e6381125e1	2cfdcf5e-487a-4c61-bdbd-e5acbac726d0	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
e24b5bd1-f60c-4912-8250-6fe2bda024be	64ee34d2-0972-4170-a5f4-838695ad595e	4bc260bc-d95a-4a8b-84c1-c7c6cdbdfced	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
8fa06341-7980-42dc-9c10-7eee329641a1	98450c22-a798-42c4-89e6-f7737be16b58	4bc260bc-d95a-4a8b-84c1-c7c6cdbdfced	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
c2539c99-fa90-4137-bf90-10c38ba61bb6	8f72fe51-a81d-4fe0-97e9-37636b0f3bd2	6d0112a9-81c0-4184-b317-f24c886f9ae5	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
8953efa6-7e51-43aa-a7e4-a84102c461ba	66c8b78e-ed88-4aeb-b856-30b2c413527b	796f3f70-b86a-417d-8f17-9f928882d824	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
548f1782-f517-4c0d-8fd2-9d9c0091c047	cfa55cbb-6646-4d98-8de1-047194fdbce1	796f3f70-b86a-417d-8f17-9f928882d824	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
c76c304c-64cb-48ba-ade9-9a5eceaf19b4	c8e6a39c-564b-422f-b9a4-45b0bc179cb6	796f3f70-b86a-417d-8f17-9f928882d824	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
326ada9b-8106-4da3-b1a0-6e1c28674d7d	de40f5e6-ee92-4aba-89a1-d413c6dbf37c	e3b64b8a-7dbb-42d5-8788-c759084e49a0	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
cc908d3b-1a41-4829-b55c-599e65e75e0f	26f36e96-2965-4927-90ca-a548f22874db	bd366d6c-718f-4ee4-ac11-1b2b0dbaa8c2	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
f7e89665-63fd-4760-ad48-df82849f575d	4d49c54b-cf07-4fc0-9171-b15369254083	d958c1ac-c2c8-47d2-80de-f001c7b44705	18fa6ec8-afd8-40b2-b468-adc78bd6be12	\N	\N	1.0	\N	\N	\N	\N	1	1	2026-08-11 00:17:48.125504+00	2026-08-11 00:17:48.125504+00	\N
\.


--
-- Data for Name: ingredient_categories; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: ingredient_categories_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: ingredient_health_flags; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: ingredient_search_index; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: ingredient_translations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: ingredients_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingredients_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
f40531d5-d865-4cba-802c-3b88aa7bd317	03620dd4-331d-438b-b77e-80647da17601	1	\N	\N	created	\N	\N	\N	\N	1.0	MILK	Milk	Milk ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	d5afb6b4c8657bf4b8ff84f116505ae011e601d1a62be4d8f2b24408d6782d9a	f4ff19755a52f1abf8871b530f78ea88820ea4cba3e40f63df674f2b99bed702	draft
b915ff91-dc68-4490-9616-def523d5c5ed	c16e7813-6912-4fe6-9c32-58f7395debbf	1	\N	\N	created	\N	\N	\N	\N	1.0	WHEY	Whey	Milk-derived whey protein	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	203163ada20a6a2d43ac6f4ee3d6dbd8599aa366caf9494b314d42da3dbd2d5b	05a3fb26c3768f6309eef57b5da09a15759bc3eed5f6634e04e2497fd935012f	draft
3c846681-105d-4c77-a65a-7c2ab84d9314	c8631d1a-bbb9-472e-9a69-3135675fef7f	1	\N	\N	created	\N	\N	\N	\N	1.0	CASEIN	Casein	Milk-derived protein	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	8b17e11cb32c814d2d592326ac21e1986324f439beffe1f7aa0810451e467527	879b41046c83519cb0223f59fc3a6e5bd4ab3a507a8e98948fa659f950d4409f	draft
03865fb3-b7bb-4c44-92d8-15b85156485b	5fabfd34-8dcb-402f-88f0-3aef87155bb1	1	\N	\N	created	\N	\N	\N	\N	1.0	LACTOSE	Lactose	Milk sugar	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	88ea64efb48f8c38afbf1ba5c08bba5409b68e8c3a7941907ba94e99b4ae21d6	bde1f420720edebd2e94759458e88a1244b07838690a31163d2e39179efab6e5	draft
bae90bee-1e88-4d09-918d-ae47e9443cce	ffe10640-a09c-435d-845b-47a5316ffc13	1	\N	\N	created	\N	\N	\N	\N	1.0	EGG	Egg	Egg ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	0f8dd7cb08b1dce83a28620096271b790e6b447fe3514e49a2f049cd425e397f	7c3f673fd033c0e28cb345c895a32e7fdd2f13209998bff645979ed380d25002	draft
b50dcc65-0b0d-44ba-b333-0e0a3bd8703a	799ca946-566f-40a1-bab2-4a58876656c9	1	\N	\N	created	\N	\N	\N	\N	1.0	EGG_WHITE	Egg White	Egg white ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	97e9a104b479f3ea851a01faa04e7980a65a933ca02bc1b35f8bfc020b6c9778	88b14d63689f8410662832d57e4dd9a69504c52c253dc1e083b7d8b8e70f0875	draft
eac8d06b-6810-45b7-a807-c45abbfc9f6c	6941d019-fca8-4e52-982c-86649246b9f1	1	\N	\N	created	\N	\N	\N	\N	1.0	EGG_YOLK	Egg Yolk	Egg yolk ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	918b06a3c57f062ca2d3918b48bf9ff478b01714f5a7f9801f446c2d1ede2cd6	5b5e24ec68c83e3e3d7f1c89533a4e230bc3b134a43de0ab6f620d3ef77c7f32	draft
50228022-ada2-4d6a-92ad-68d4cd86c99f	bf178102-a91b-4180-9226-5ccfa8f120a6	1	\N	\N	created	\N	\N	\N	\N	1.0	PEANUT	Peanut	Peanut ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	f04b7f980372a3f52eb73290619eeae381fccb91e407f1e19902f949783312f2	f258151a4c64b142c8238d7fd2de5499718a5758e821ad22047b0adf63de8c87	draft
fd716ef9-d476-4c14-ba62-5707ec30af70	23abc89d-f2f9-4c02-8259-483889a86fcc	1	\N	\N	created	\N	\N	\N	\N	1.0	WHEAT_FLOUR	Wheat Flour	Flour made from wheat	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	36c066ddcdb7983d804945aabd6310b4bc88148359d9ec3b9be0e0a6d38ccb73	08c3d7f329556317a3b5609a55e674b5f39a1e4c8930bba12acd8293ee51daa3	draft
e6b7f10e-b077-41b4-a8e1-475ae92d6b63	06f213a4-6e6f-46b8-8be8-28e6381125e1	1	\N	\N	created	\N	\N	\N	\N	1.0	WHEAT	Wheat	Wheat ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	c98b6ed1d295bd5594457e73a9df737ad52a43657439cece3f463e8174d14910	1815a32ec76a9e6f3b977ebb6780b17f108c3af3c62b449d636489628c5b26b6	draft
81bdfab1-1d77-4e04-b2e4-bff946a71c45	64ee34d2-0972-4170-a5f4-838695ad595e	1	\N	\N	created	\N	\N	\N	\N	1.0	SOY	Soy	Soybean ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	b1ca3a129bbca5ddd7058a27d6ef5e003c3a435c67a7c85dfefcbc6295ac72dd	9cfefc47489b4fe2c6873ca0d5d07609ee50d85d68941c18d65f65f3c697c312	draft
fd99de13-0b57-4485-bcf6-7f66ab93bc51	98450c22-a798-42c4-89e6-f7737be16b58	1	\N	\N	created	\N	\N	\N	\N	1.0	SOY_LECITHIN	Soy Lecithin	Lecithin derived from soybean	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	677f0b6ef4da04ebf957ae76045bb761fc693cb34cf65d8021baaec811490e46	8715e82d8775a9c507d5eace4898418b53ab5481619de4f12be3bf62f780f981	draft
e801e0fc-5bad-46ec-944d-ffc731c69958	8f72fe51-a81d-4fe0-97e9-37636b0f3bd2	1	\N	\N	created	\N	\N	\N	\N	1.0	SESAME	Sesame	Sesame ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	969f3eb76b3830d90edaed5eb60eb393c76d5872de62a6c31225ba679d9121f1	e549072aff41abdb5a7fdd67159c4c5b1643713a5660da69a30fdd7395ef1e65	draft
95e22ff3-db88-4bd0-91e6-bf863fa53593	66c8b78e-ed88-4aeb-b856-30b2c413527b	1	\N	\N	created	\N	\N	\N	\N	1.0	ALMOND	Almond	Tree nut almond	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	89a6546f0f097737ed2f53b32a72c104d814438ae60361aa73c2979bf1f73bf6	eae3e26498a1994daf52ecfafbde54ca65321efcef6835a7334d280c73eda5d1	draft
7697031a-5e46-4336-b7e2-b61460691831	cfa55cbb-6646-4d98-8de1-047194fdbce1	1	\N	\N	created	\N	\N	\N	\N	1.0	CASHEW	Cashew	Tree nut cashew	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	47acd9b6608593936663661ccd474edd398c5c303c99cb5c5a36c97234b52216	c3ff57e8c1a1df558e082698b2fab01d2481cbae811ffb33beb630f20b090164	draft
85abc2df-04b1-43ef-84b0-6d71ce884dfc	c8e6a39c-564b-422f-b9a4-45b0bc179cb6	1	\N	\N	created	\N	\N	\N	\N	1.0	WALNUT	Walnut	Tree nut walnut	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	c15a7dbd6987608dfde1e60a42d625404ae64bb0e4a3175f9d23b85e0807455b	8731357aa1be9ca15fd57caf6f80752c5215793b2072d7f0544daba100776a1e	draft
6b7389e6-3936-4db3-883e-09c6327abd11	de40f5e6-ee92-4aba-89a1-d413c6dbf37c	1	\N	\N	created	\N	\N	\N	\N	1.0	FISH	Fish	Fish ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	d6af4c9f5a07bfb0bc3ea39d5263401a1df8a7834fda51b18ed9f408f79860c7	1ebbfa4315f290d7e841a0cf9020ae155ee6e2ddf6c36ec7c1b32a65c3b53cc2	draft
8f3e80f8-668d-4534-9f59-74427ec4a195	26f36e96-2965-4927-90ca-a548f22874db	1	\N	\N	created	\N	\N	\N	\N	1.0	SHRIMP	Shrimp	Crustacean ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	6eb34f3269846c6d57054d43f8c1932c6d1e5a6fc1b8271aaf83016c61d2985e	e11809614ce7ef86171f92f03093a9170f42f0b1ba2eea66917abb313d368d19	draft
b5f5a3df-eb40-4cee-90f3-d438456cfb63	4d49c54b-cf07-4fc0-9171-b15369254083	1	\N	\N	created	\N	\N	\N	\N	1.0	MUSTARD	Mustard	Mustard ingredient	1	\N	\N	\N	\N	2026-08-11 00:17:47.305371+00	2026-08-11 00:17:47.305371+00	\N	\N	3a6379e06be2c7c3961078af6b5dd926444c269e4b5612310a50edbfb8235aa0	66895087c156bd09ecbe10782d54e3eaf09e2d94c502a4e16f857b5d16db28ac	draft
\.


--
-- Data for Name: measurement_bases; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: nutrition_type_translations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: nutrition_types_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: permission_types; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.products (id, brand_id, product_category_id, internal_code, name, description, status_id, source_id, confidence_level, verified_at, approved_at, deprecated_at, version_number, created_by, approved_by, created_at, updated_at, deleted_at) FROM stdin;
523b923e-2e00-424f-b6eb-8e8797a06025	a03497f8-562e-4b20-a98c-8ec497c5bccd	\N	FATEEN_MILK_TEST	Fateen Test Milk	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:29:12.621739+00	2026-08-11 00:29:12.621739+00	\N
cd029de1-856f-4952-b1ed-cd0cb2b06879	a03497f8-562e-4b20-a98c-8ec497c5bccd	\N	FATEEN_SNACK_TEST	Fateen Test Snack	\N	1	\N	0.5	\N	\N	\N	1	\N	\N	2026-08-11 00:29:12.968864+00	2026-08-11 00:29:12.968864+00	\N
5c1df2b4-e59d-424d-a4b5-ddd1311e7b34	e98ff5f4-5a2f-4b38-93b9-37d78707f98a	\N	TEST_MILK_001	Test Milk Product	\N	1	\N	0.5	\N	\N	\N	2	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:50.216011+00	\N
1915540e-716f-4ed1-93c0-208f79b95245	feec1927-2905-470e-86bd-47f2673dadb8	\N	TEST_BREAD_001	Test Wheat Bread	\N	1	\N	0.5	\N	\N	\N	2	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:50.671479+00	\N
92a49394-f8bd-4969-9dce-7ffa05e97feb	b9a7338b-4432-4292-85ea-6d3a80e193ff	\N	TEST_CHOCOLATE_001	Test Milk Chocolate	\N	1	\N	0.5	\N	\N	\N	2	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:51.113929+00	\N
d743db46-c247-4217-a28f-0063189f41eb	84926a6b-f834-48cb-b8b8-4cbe8cdda5e2	\N	TEST_CHIPS_001	Test Potato Chips	\N	1	\N	0.5	\N	\N	\N	2	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:51.56078+00	\N
b6cd3e32-ca24-496b-b5fa-8ea3f8bed5c2	c0c7d43a-fdd0-4dc3-99d8-fa2fb488337f	\N	TEST_BISCUIT_001	Test Wheat Biscuit	\N	1	\N	0.5	\N	\N	\N	2	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:52.042078+00	\N
\.


--
-- Data for Name: product_allergens; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_barcodes; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_barcodes_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_categories_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_category_translations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_health_flags; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_images; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_images_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_ingredients; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_nutrition_values; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_search_index; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: product_translations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: products_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.products_history (id, original_entity_id, version_number, previous_version_id, change_set_id, change_type, change_reason, changed_by, approved_by, source_id, confidence_level, brand_id, product_category_id, internal_code, name, description, status_id, verified_at, approved_at, deprecated_at, deleted_at, created_at, effective_from, effective_to, superseded_at, snapshot_hash, checksum, version_status) FROM stdin;
fc12e1e6-9cc4-4471-8d7a-c7f6f8be85d5	523b923e-2e00-424f-b6eb-8e8797a06025	1	\N	\N	created	\N	\N	\N	\N	0.5	a03497f8-562e-4b20-a98c-8ec497c5bccd	\N	FATEEN_MILK_TEST	Fateen Test Milk	\N	1	\N	\N	\N	\N	2026-08-11 00:29:12.621739+00	2026-08-11 00:29:12.621739+00	\N	\N	701022e560a4f9cc27e1718f6ed0e019d8cb3a98c224c7a63ba0e98b36ac1b2c	473e3edfbb28fabe8bdecaa69ae528156377773c7baa45ef87f8475e73f83c29	draft
eeb64918-d60e-4ca5-8c8b-49678e797d7d	cd029de1-856f-4952-b1ed-cd0cb2b06879	1	\N	\N	created	\N	\N	\N	\N	0.5	a03497f8-562e-4b20-a98c-8ec497c5bccd	\N	FATEEN_SNACK_TEST	Fateen Test Snack	\N	1	\N	\N	\N	\N	2026-08-11 00:29:12.968864+00	2026-08-11 00:29:12.968864+00	\N	\N	db79829a1da2017065b68ce0619771623bcb37ed64086d556323f6bb2ec7e47e	f8ee81b73bd8e69553f1569277e2c30d4b3afa7b20f7762c0c4f80cae4ab83ba	draft
b4c5e9eb-90db-4cec-898a-a5a3bd1e042b	5c1df2b4-e59d-424d-a4b5-ddd1311e7b34	1	\N	\N	created	\N	\N	\N	\N	0.5	\N	\N	TEST_MILK_001	Test Milk Product	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:31:20.214268+00	\N	\N	4a4e3e9fc26260204ee5c9ef77f0258969f2ad082b06e99f5784a3933163fb8a	e094e7fe940d54833669c63d78d0679fc23445cebd3a37f30614b7c0d906d097	draft
33247354-e818-4c78-ad30-5dd19c8ab2ec	1915540e-716f-4ed1-93c0-208f79b95245	1	\N	\N	created	\N	\N	\N	\N	0.5	\N	\N	TEST_BREAD_001	Test Wheat Bread	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:31:20.214268+00	\N	\N	bc2874212e132992814f370c3ceedc937c010d7ca94924f2fe76bc47945c3dcb	db2ecd3636e0a8b79fb7d8664d073082b2e26d0e65a258fb8574ce4a9753080a	draft
8c2b1524-6f05-4efb-a95e-e4ecb60ccdb5	92a49394-f8bd-4969-9dce-7ffa05e97feb	1	\N	\N	created	\N	\N	\N	\N	0.5	\N	\N	TEST_CHOCOLATE_001	Test Milk Chocolate	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:31:20.214268+00	\N	\N	babb51ade6e9b0f629c850806cc2f6682c7e262f81a3331e704b77bb725c06b7	2976c17a8a18cc4dae028f15d091657807a97207bf9793b931fad462ebf31ddd	draft
6f2f0243-2c2f-4168-aa18-7e320e689897	d743db46-c247-4217-a28f-0063189f41eb	1	\N	\N	created	\N	\N	\N	\N	0.5	\N	\N	TEST_CHIPS_001	Test Potato Chips	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:31:20.214268+00	\N	\N	e83e62cf9f88ced404540a91f982f19a053f449713863c5117ddc950ae1dd631	09a9602966d7cf068a39dc8cc1cdeb3004135215e77ffd8673013ece4e032e94	draft
ee5dc36c-f6af-4297-b79a-f12ec7884676	b6cd3e32-ca24-496b-b5fa-8ea3f8bed5c2	1	\N	\N	created	\N	\N	\N	\N	0.5	\N	\N	TEST_BISCUIT_001	Test Wheat Biscuit	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:31:20.214268+00	\N	\N	16ee249e98901c8cee46c1521c3a7473d87078b5d22fd3427af39c7603111e1d	42b4435be7781e966eca380fae3eee3cf8890a69d87db91680cc680784b7653f	draft
2438a097-aa7b-4cdb-87e6-dae10c95c13b	5c1df2b4-e59d-424d-a4b5-ddd1311e7b34	2	b4c5e9eb-90db-4cec-898a-a5a3bd1e042b	\N	modified	\N	\N	\N	\N	0.5	e98ff5f4-5a2f-4b38-93b9-37d78707f98a	\N	TEST_MILK_001	Test Milk Product	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:50.216011+00	\N	\N	60ce8d95d568014f8fc88b04662734b54bf1620f0890d9b1759fa300bfbc0185	d4732345e2515f40967e7d6db2f2248eae07163e3587f907b5731b24207b10fd	draft
933e1bea-26f2-4a24-957b-f5f36be083fc	1915540e-716f-4ed1-93c0-208f79b95245	2	33247354-e818-4c78-ad30-5dd19c8ab2ec	\N	modified	\N	\N	\N	\N	0.5	feec1927-2905-470e-86bd-47f2673dadb8	\N	TEST_BREAD_001	Test Wheat Bread	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:50.671479+00	\N	\N	4aff86a2041d3619dcdf5bef6ca783999a66c317199bbcdb9af08392aa245bdc	6a74b445a3f1288fbf26ffa22cbd5fc0d8469e1953fe2af2195cfcd8d1200985	draft
13dfad82-24ab-4df3-9dd6-bb6c413e8be4	92a49394-f8bd-4969-9dce-7ffa05e97feb	2	8c2b1524-6f05-4efb-a95e-e4ecb60ccdb5	\N	modified	\N	\N	\N	\N	0.5	b9a7338b-4432-4292-85ea-6d3a80e193ff	\N	TEST_CHOCOLATE_001	Test Milk Chocolate	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:51.113929+00	\N	\N	26172054b8ce38f93aa53e867c108f886f26b81b2d2052174e2003233f26f6b9	9a9ded86ae35d833e2df8f2376481ef0d8ebe48ed4b59d413cb53fc3b72b1757	draft
fb539f38-9904-47c1-bb03-015dbdc5bfd3	d743db46-c247-4217-a28f-0063189f41eb	2	6f2f0243-2c2f-4168-aa18-7e320e689897	\N	modified	\N	\N	\N	\N	0.5	84926a6b-f834-48cb-b8b8-4cbe8cdda5e2	\N	TEST_CHIPS_001	Test Potato Chips	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:51.56078+00	\N	\N	f882a766ab37b48ce6a6897a99e7312868c270b01caba0ca1647c8acdf9f9ca7	ba1b25b11d385ff460ab58bae73852504de900f5193fc1c8859be3dc3fd3605c	draft
e2d28d02-3b96-4687-9fbf-5bca8db9b024	b6cd3e32-ca24-496b-b5fa-8ea3f8bed5c2	2	ee5dc36c-f6af-4297-b79a-f12ec7884676	\N	modified	\N	\N	\N	\N	0.5	c0c7d43a-fdd0-4dc3-99d8-fa2fb488337f	\N	TEST_BISCUIT_001	Test Wheat Biscuit	\N	1	\N	\N	\N	\N	2026-08-11 00:31:20.214268+00	2026-08-11 00:40:52.042078+00	\N	\N	0471cf66a2cb10db9df2d04dbabe829e3d32eb0486322cd56d13e6c777a64fc4	670e185ad866078c00d3eb39e822979d3eee769ec17bb8bd8bd205531e030b06	draft
\.


--
-- Data for Name: regions; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: regulatory_authorities; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schema_migrations (version, checksum, applied_at) FROM stdin;
0001_foundation_extensions.sql	25cc78dc2c82da967b3ed1338b0f1087	2026-08-10 11:16:57.832627+00
0002_foundation_enums.sql	e0c797db5c912ed5613dc762cca3063f	2026-08-10 11:16:58.655214+00
0003_foundation_lookup_tables.sql	c3de325fcd3928738cf22210298543ea	2026-08-10 11:16:59.275743+00
0004_foundation_lookup_constraints.sql	78004c298fbc2729f7318244c9dfde48	2026-08-10 11:16:59.690699+00
0005_foundation_lookup_indexes.sql	f8c1138c6c246460b82657d1b3ee85de	2026-08-10 11:17:00.096347+00
0006_foundation_functions_and_triggers.sql	148d20aa8b4202f8c9f9260f2af78d59	2026-08-10 11:17:00.57102+00
0007_seed_lifecycle_statuses.sql	d62d81be6dff947f2ba004122c0d5443	2026-08-10 11:17:01.031861+00
0008_foundation_reference_tables.sql	93b1a804ef858bea08dc74490b8a13ce	2026-08-10 11:17:01.451508+00
0009_foundation_reference_constraints.sql	49aa2095a830f9a4eaca123bf13f9634	2026-08-10 11:17:02.025+00
0010_foundation_reference_indexes.sql	dfb66d28c9adec07a4fbe6dd53427af4	2026-08-10 11:17:02.56403+00
0011_foundation_reference_triggers.sql	663584c192306127b511e17a12d77ffd	2026-08-10 11:17:03.035729+00
0012_core_entity_tables.sql	99aea0d3a591f7e3e724bc3d7a248cb1	2026-08-10 11:17:03.549921+00
0013_core_entity_constraints.sql	11fd9da61ed144808b5e31b9cb9935d7	2026-08-10 11:17:04.042426+00
0014_core_entity_indexes.sql	3458b293eb2477466345009c5d82483a	2026-08-10 11:17:04.577219+00
0015_core_entity_triggers.sql	b7ac049beaf5f3a9d86c2a6a86806b82	2026-08-10 11:17:05.165553+00
0016_relationship_tables.sql	ddde14275144f4dbe7cdc08e4aae50ac	2026-08-10 11:17:05.682562+00
0017_relationship_constraints.sql	17e8e5fa1a307c5e58eb738c4ab99c5b	2026-08-10 11:17:06.293292+00
0018_relationship_indexes.sql	c3b56e6fbb62d42837c8e221a9376193	2026-08-10 11:17:06.834448+00
0019_relationship_triggers.sql	6fdea2f270528758f6185d9fc04cd976	2026-08-10 11:17:07.474779+00
0020_history_tables.sql	a21be62cd97eaf97c32de37491c08fe0	2026-08-10 11:17:08.020253+00
0021_audit_tables.sql	5f9fe5b1549ef2434f779b13feab31af	2026-08-10 11:17:08.533803+00
0022_history_constraints.sql	7ec56ec2f0c35af0e43be93b6e862094	2026-08-10 11:17:09.085866+00
0023_history_indexes.sql	e815102c5daf807a6ddf30beb7d2c4dd	2026-08-10 11:17:09.625441+00
0024_history_triggers.sql	02f4b13d07001996e024aefb0a1c829e	2026-08-10 11:17:10.237211+00
0025_media_and_barcode_tables.sql	eca1b773266de2e9e7db84e91fbfcd2c	2026-08-10 11:17:10.735624+00
0026_media_and_barcode_history_tables.sql	c11fd64de3f6d35bafb32de03ae645d9	2026-08-10 11:17:11.332809+00
0027_media_and_barcode_constraints.sql	299a23749caa51c0b33ecf087a1cdb04	2026-08-10 11:17:11.989088+00
0028_media_and_barcode_indexes.sql	8acd991a77706b423f331ae338fbfe8e	2026-08-10 11:17:12.62044+00
0029_media_and_barcode_triggers.sql	64d565367af8f72a07bdab67eb3be3c1	2026-08-10 11:17:13.164927+00
0030_search_tables.sql	709b5bb9245af87e0cdef7c40859f639	2026-08-10 11:17:13.737559+00
0031_search_indexes.sql	518529bfce1cc341d1e5f7e475aa7028	2026-08-10 11:17:14.292334+00
0032_ecr_product_media_tables.sql	e55839faadedb0f4bb5d8f2423def7a0	2026-08-10 11:17:14.842674+00
0033_ecr_product_media_history_tables.sql	66e4f296e4ced002dfe2a11205231390	2026-08-10 11:17:15.424554+00
0034_ecr_constraints.sql	8d07dafba7c34f7869a1e5384d33c1f7	2026-08-10 11:17:16.014675+00
0035_ecr_indexes.sql	4e2af1e1fe6239c84ee3d64b7b784130	2026-08-10 11:17:16.617188+00
0036_ecr_functions.sql	e097206ebc621a92a59a0a2d915e056e	2026-08-10 11:17:17.198845+00
0037_ecr_triggers.sql	7ef1e8e7eb34969ec07d963930af5983	2026-08-10 11:17:17.739675+00
0038_ecr_fix_capture_history.sql	1a2103a5ca1a5d8afa8e342689762596	2026-08-10 11:17:18.289189+00
0039_ecr_fix_history_original_entity_fk.sql	665f2ffe22fa523551ed67ee07c7aec4	2026-08-10 11:17:18.900113+00
\.


--
-- Data for Name: version_metadata; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Name: lifecycle_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lifecycle_statuses_id_seq', 3, true);


--
-- PostgreSQL database dump complete
--

\unrestrict vePCSWivNeBRguDmNJ1e2QuELeQicUm5aCOuifizYxdfDh7noej5zmIhrRcfHsm

