--
-- PostgreSQL database dump
--

\restrict mhgkOM4Q1x5ZVFT9bD7qs8fj3YHlJHMOasGwhtEKgmTENg89T2OyxluecoYIR4I

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
-- Data for Name: source_priorities; Type: TABLE DATA; Schema: public; Owner: fateen
--

INSERT INTO public.source_priorities VALUES ('b9957035-26e7-4c3c-8d99-a6a582d07eaa', 'TEST', 'Test Source', 99, 'Internal priority for controlled Fateen test data.', 1, 1, '2026-08-12 13:55:13.845982+00', '2026-08-12 13:55:13.845982+00', NULL);


--
-- Data for Name: data_sources; Type: TABLE DATA; Schema: public; Owner: fateen
--

INSERT INTO public.data_sources VALUES ('65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'FATEEN_TEST', 'Fateen Internal Test Dataset', 'Controlled test data used for database integration validation.', '99a00982-9129-4753-afe3-60f56aae2875', 'b9957035-26e7-4c3c-8d99-a6a582d07eaa', NULL, false, 1, 1, '2026-08-12 13:55:13.845982+00', '2026-08-12 13:55:13.845982+00', NULL);


--
-- Data for Name: product_allergens; Type: TABLE DATA; Schema: public; Owner: fateen
--

INSERT INTO public.product_allergens VALUES ('4b80d265-c4e2-4d8b-98e4-f765ac4f5f00', '1915540e-716f-4ed1-93c0-208f79b95245', '2cfdcf5e-487a-4c61-bdbd-e5acbac726d0', '18fa6ec8-afd8-40b2-b468-adc78bd6be12', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_allergens VALUES ('c0ac5ec0-0d62-4dff-b287-bdedf1c6669b', '523b923e-2e00-424f-b6eb-8e8797a06025', '5c302be6-3afe-4ed7-919c-c308158bc54e', '18fa6ec8-afd8-40b2-b468-adc78bd6be12', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_allergens VALUES ('81dc6323-7b02-425b-8b67-4a77839ce01c', '5c1df2b4-e59d-424d-a4b5-ddd1311e7b34', '5c302be6-3afe-4ed7-919c-c308158bc54e', '18fa6ec8-afd8-40b2-b468-adc78bd6be12', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_allergens VALUES ('2c107f37-e5e6-4592-af1a-9c40ae46e437', '92a49394-f8bd-4969-9dce-7ffa05e97feb', '5c302be6-3afe-4ed7-919c-c308158bc54e', '18fa6ec8-afd8-40b2-b468-adc78bd6be12', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_allergens VALUES ('6aab2855-a77a-49fe-b448-835e60e134f3', 'b6cd3e32-ca24-496b-b5fa-8ea3f8bed5c2', '2cfdcf5e-487a-4c61-bdbd-e5acbac726d0', '18fa6ec8-afd8-40b2-b468-adc78bd6be12', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_allergens VALUES ('34340aef-a485-4b71-ae12-251acc8c1654', 'cd029de1-856f-4952-b1ed-cd0cb2b06879', 'f62d44e1-1646-450a-b8ee-2a6adf6cd7cd', '18fa6ec8-afd8-40b2-b468-adc78bd6be12', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_allergens VALUES ('7e0273ce-beae-41fc-9fab-a1963b019512', 'd743db46-c247-4217-a28f-0063189f41eb', '4bc260bc-d95a-4a8b-84c1-c7c6cdbdfced', '18fa6ec8-afd8-40b2-b468-adc78bd6be12', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);


--
-- Data for Name: product_barcodes; Type: TABLE DATA; Schema: public; Owner: fateen
--

INSERT INTO public.product_barcodes VALUES ('e6bca23b-dfae-43fc-8ced-cdc36692307c', 'cd029de1-856f-4952-b1ed-cd0cb2b06879', '1735210f-d5ad-476d-9e36-da15f3584a2c', '7489a8be-be9a-4f22-b472-96f7140295be', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 18:00:11.498008+00', '2026-08-12 18:00:11.498008+00', NULL);
INSERT INTO public.product_barcodes VALUES ('2298d454-4b8f-4c4f-a64d-986d05c24059', 'd743db46-c247-4217-a28f-0063189f41eb', '627e6069-b55a-42b1-8ffa-c5b03c67877e', '7489a8be-be9a-4f22-b472-96f7140295be', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 18:00:11.498008+00', '2026-08-12 18:00:11.498008+00', NULL);
INSERT INTO public.product_barcodes VALUES ('343b2a3c-8688-47cc-a63d-f9ae6683bd26', '523b923e-2e00-424f-b6eb-8e8797a06025', '2a491400-4249-4466-afee-36ca917f35ed', '7489a8be-be9a-4f22-b472-96f7140295be', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 18:00:11.498008+00', '2026-08-12 18:00:11.498008+00', NULL);
INSERT INTO public.product_barcodes VALUES ('a8ce1cef-102f-4f67-b4fc-f50d95ccccc5', 'b6cd3e32-ca24-496b-b5fa-8ea3f8bed5c2', 'e8dc8a10-8560-4e57-851f-05c83c5570ec', '7489a8be-be9a-4f22-b472-96f7140295be', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 18:00:11.498008+00', '2026-08-12 18:00:11.498008+00', NULL);
INSERT INTO public.product_barcodes VALUES ('bfdab0db-56c2-48dc-883c-22da4c8e8dd1', '5c1df2b4-e59d-424d-a4b5-ddd1311e7b34', '5088e20c-e943-4a4b-aa1d-602a4e3dccff', '7489a8be-be9a-4f22-b472-96f7140295be', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 18:00:11.498008+00', '2026-08-12 18:00:11.498008+00', NULL);
INSERT INTO public.product_barcodes VALUES ('483ab0eb-7837-4f0e-be43-45a5f89466f4', '92a49394-f8bd-4969-9dce-7ffa05e97feb', '28532d4a-6776-44ec-b86e-3fd3b4f67403', '7489a8be-be9a-4f22-b472-96f7140295be', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 18:00:11.498008+00', '2026-08-12 18:00:11.498008+00', NULL);
INSERT INTO public.product_barcodes VALUES ('6b8c3945-cc49-4fb7-968c-e9413bffc34c', '1915540e-716f-4ed1-93c0-208f79b95245', 'b4b93651-7600-4992-ae9b-2604e917f4aa', '7489a8be-be9a-4f22-b472-96f7140295be', '65e8a675-805d-49a2-87ad-d3b62a9ba86d', '8b8071bd-53f4-4896-9587-d0114af571c3', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 18:00:11.498008+00', '2026-08-12 18:00:11.498008+00', NULL);


--
-- Data for Name: product_ingredients; Type: TABLE DATA; Schema: public; Owner: fateen
--

INSERT INTO public.product_ingredients VALUES ('e0c83c6f-f3ba-4ff3-98e9-f40352520de2', '523b923e-2e00-424f-b6eb-8e8797a06025', '03620dd4-331d-438b-b77e-80647da17601', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('933cb5b7-cf00-40e8-bd1c-29214e91812d', 'cd029de1-856f-4952-b1ed-cd0cb2b06879', 'bf178102-a91b-4180-9226-5ccfa8f120a6', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('b006b3dc-4266-497b-8278-05d01534d3a9', '5c1df2b4-e59d-424d-a4b5-ddd1311e7b34', '03620dd4-331d-438b-b77e-80647da17601', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('75065166-bb6f-40d1-8321-326d0f768851', '5c1df2b4-e59d-424d-a4b5-ddd1311e7b34', 'c16e7813-6912-4fe6-9c32-58f7395debbf', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('6b1c5e67-dcd8-4a2b-b56d-36fc072f5b25', '5c1df2b4-e59d-424d-a4b5-ddd1311e7b34', 'c8631d1a-bbb9-472e-9a69-3135675fef7f', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('e0d5c329-0a4d-479e-8b36-76077d37d388', '5c1df2b4-e59d-424d-a4b5-ddd1311e7b34', '5fabfd34-8dcb-402f-88f0-3aef87155bb1', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('645651b8-a38f-4c53-b9ba-8c3b6cc3ce18', '1915540e-716f-4ed1-93c0-208f79b95245', '23abc89d-f2f9-4c02-8259-483889a86fcc', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('bc9f96c4-9ee2-4814-8af4-ff3397012476', '1915540e-716f-4ed1-93c0-208f79b95245', '06f213a4-6e6f-46b8-8be8-28e6381125e1', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('eab08cb1-8334-4d65-8494-6735a1b8fab5', '92a49394-f8bd-4969-9dce-7ffa05e97feb', '03620dd4-331d-438b-b77e-80647da17601', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('0bc7cabd-4fa9-42e8-9bb5-8f156685021c', '92a49394-f8bd-4969-9dce-7ffa05e97feb', 'c8631d1a-bbb9-472e-9a69-3135675fef7f', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('3105a90d-d56a-48e6-8267-11bceb27c52b', 'd743db46-c247-4217-a28f-0063189f41eb', '98450c22-a798-42c4-89e6-f7737be16b58', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('cc31fdc1-2942-4926-a61a-317d861dc3e4', 'b6cd3e32-ca24-496b-b5fa-8ea3f8bed5c2', '23abc89d-f2f9-4c02-8259-483889a86fcc', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);
INSERT INTO public.product_ingredients VALUES ('4409f53c-633d-4e8e-8b17-ec4a201817ae', 'b6cd3e32-ca24-496b-b5fa-8ea3f8bed5c2', '06f213a4-6e6f-46b8-8be8-28e6381125e1', 'ce47dde0-5a33-4cfd-9751-44bb4f4a58d2', NULL, NULL, '65e8a675-805d-49a2-87ad-d3b62a9ba86d', 'c24d31c8-beda-4579-a81c-9ca44d430170', 1.0, NULL, NULL, NULL, NULL, 1, 1, '2026-08-12 17:57:43.00436+00', '2026-08-12 17:57:43.00436+00', NULL);


--
-- PostgreSQL database dump complete
--

\unrestrict mhgkOM4Q1x5ZVFT9bD7qs8fj3YHlJHMOasGwhtEKgmTENg89T2OyxluecoYIR4I

