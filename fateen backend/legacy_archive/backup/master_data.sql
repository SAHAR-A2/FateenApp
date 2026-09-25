--
-- PostgreSQL database dump
--

\restrict MYI1Hp3cOTMtaSICTot9p0bA9Cgs2dzVgLRaFlhbG84sj8wQRyP51ZeHo7w4d0k

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
-- Data for Name: allergen_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.allergen_types (id, code, name, description, display_order, status_id, version_number, created_at, updated_at, deleted_at) FROM stdin;
b4ef879c-7d2c-443b-9435-055c9a442fb7	FOOD_ALLERGEN	Food Allergen	\N	0	1	1	2026-08-11 00:13:04.177607+00	2026-08-11 00:13:04.177607+00	\N
8affd3a9-4bd2-49a8-9183-b276c4d24ab2	DIETARY_RESTRICTION	Dietary Restriction	\N	0	1	1	2026-08-11 00:13:04.177607+00	2026-08-11 00:13:04.177607+00	\N
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
-- PostgreSQL database dump complete
--

\unrestrict MYI1Hp3cOTMtaSICTot9p0bA9Cgs2dzVgLRaFlhbG84sj8wQRyP51ZeHo7w4d0k

