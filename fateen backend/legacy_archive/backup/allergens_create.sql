-- Name: TABLE allergen_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.allergen_types IS 'Governed registry of allergen classes (business knowledge, not ENUM).';


--
-- Name: COLUMN allergen_types.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergen_types.code IS 'Stable machine reference (snake_case), e.g. gluten, tree_nuts, sesame.';


--
-- Name: COLUMN allergen_types.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergen_types.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


--
-- Name: allergens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allergens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    allergen_type_id uuid,
    internal_code public.citext NOT NULL,
    name text NOT NULL,
    description text,
    status_id bigint NOT NULL,
    source_id uuid,
    confidence_level numeric DEFAULT 0.5 NOT NULL,
    verified_at timestamp with time zone,
    approved_at timestamp with time zone,
    deprecated_at timestamp with time zone,
    version_number integer DEFAULT 1 NOT NULL,
    created_by uuid,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT allergens_confidence_level_check CHECK (((confidence_level >= (0)::numeric) AND (confidence_level <= (1)::numeric))),
    CONSTRAINT allergens_version_number_check CHECK ((version_number > 0))
);


--
-- Name: TABLE allergens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.allergens IS 'Canonical registry of specific allergens (governed, provenance-tracked entity).';


--
-- Name: COLUMN allergens.allergen_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.allergen_type_id IS 'Allergen class (foreign key to allergen_types); NULL when not yet classified.';


--
-- Name: COLUMN allergens.internal_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.internal_code IS 'Stable internal machine reference (unique, citext).';


--
-- Name: COLUMN allergens.confidence_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.confidence_level IS 'Numeric fact confidence in [0,1]; the confidence_band ENUM is derived, never stored.';


--
-- Name: COLUMN allergens.version_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.version_number IS 'Monotonic governance/version counter; starts at 1, increments on governed change.';


--
-- Name: COLUMN allergens.created_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.created_by IS 'UUID of the actor that created the row; FK to the future auth service (none yet).';


--
-- Name: COLUMN allergens.approved_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.allergens.approved_by IS 'UUID of the actor that approved the row; FK to the future auth service (none yet).';


--
-- Name: allergens_history; Type: TABLE; Schema: public; Owner: -
--

