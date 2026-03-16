--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

-- Started on 2025-05-06 00:53:44

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
-- TOC entry 4 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- TOC entry 4977 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 255 (class 1255 OID 90503)
-- Name: aegumisajad(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aegumisajad(paevad integer) RETURNS TABLE("annetuse id" bigint, toiduaine character varying, kogus bigint, "säilivusaeg" date, "päevi aegumiseni" integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id::bigint,
        t.nimetus,
        at.kogus,
        at.sailivusaeg,
        (at.sailivusaeg - CURRENT_DATE)
    FROM annetused a
    JOIN annetuse_toiduained at ON a.id = at.annetus_id
    JOIN toiduained t ON at.toiduaine_id = t.id
    WHERE (at.sailivusaeg - CURRENT_DATE) <= paevad;
END;
$$;


--
-- TOC entry 254 (class 1255 OID 90490)
-- Name: hilinenud_transpordid(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hilinenud_transpordid(paevad integer) RETURNS TABLE("annetuse ID" bigint, kirjeldus character varying, "transpordi kuupäev" date, "senine transpordiaeg" integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id::bigint AS "annetuse ID",
        a.kirjeldus,
        t.transpordi_kuupaev AS "transpordi kuupäev",
        CURRENT_DATE - t.transpordi_kuupaev AS "senine transpordiaeg"
    FROM annetused a
    JOIN transpordid_annetused ta ON a.id = ta.annetus_id
    JOIN transpordid t ON ta.transport_id = t.id
    WHERE lower(t.staatus) = 'teel'
    AND (CURRENT_DATE - t.transpordi_kuupaev) > paevad;
END;
$$;


--
-- TOC entry 242 (class 1255 OID 90487)
-- Name: kas_toiduaine_eksisteerib(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.kas_toiduaine_eksisteerib() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    olemas integer;
BEGIN
    SELECT COUNT(*) INTO olemas FROM toiduained WHERE id = NEW.toiduaine_id;

    IF olemas = 0 THEN
        RAISE EXCEPTION 'Toiduaine ID % ei eksisteeri toiduainete tabelis! Lisage puuduvad toiduained see enne annetuse sisestamist!', NEW.toiduaine_id;
    END IF;

    RETURN NEW;
END;
$$;


--
-- TOC entry 241 (class 1255 OID 90486)
-- Name: lisa_annetus(bigint, character varying, date, character varying, bigint[], bigint[], date[]); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.lisa_annetus(IN p_kasutaja_id bigint, IN p_kirjeldus character varying, IN p_kuupaev date, IN p_staatus character varying, IN p_toiduaine_id bigint[], IN p_kogused bigint[], IN p_sailivusajad date[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    annetus_id bigint;
    i integer;
BEGIN
    INSERT INTO annetused(kasutaja_id, transport_id, kirjeldus, annetuse_kuupaev, staatus)
    VALUES (p_kasutaja_id, NULL, p_kirjeldus, p_kuupaev, p_staatus)
    RETURNING id INTO annetus_id;

    FOR i IN 1..array_length(p_toiduaine_id, 1) LOOP
        INSERT INTO annetuse_toiduained(annetus_id, toiduaine_id, kogus, sailivusaeg)
        VALUES (annetus_id, p_toiduaine_id[i], p_kogused[i], p_sailivusajad[i]);
    END LOOP;
END;
$$;


--
-- TOC entry 256 (class 1255 OID 90515)
-- Name: saadavalolevad_annetused(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.saadavalolevad_annetused() RETURNS TABLE("annetuse number" bigint, kirjeldus text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM (
        -- Annetuse üldandmed
        SELECT 
            a.id::bigint AS "annetuse number",
            COALESCE(k.ettevotte_nimi, k.kontaktisik) || ', ' || 
            (CURRENT_DATE - a.annetuse_kuupaev) || ' päeva tagasi' AS kirjeldus
        FROM annetused a
        JOIN kasutajad k ON a.kasutaja_id = k.id
        LEFT JOIN transpordid_annetused ta ON a.id = ta.annetus_id
        WHERE ta.transport_id IS NULL

        UNION ALL

        -- Toiduainete read
        SELECT 
            a.id::bigint AS "annetuse number",
            t.nimetus || ' (' || at.kogus || ' tk), ' || TO_CHAR(at.sailivusaeg, 'DD-MM-YYYY') AS kirjeldus
        FROM annetused a
        JOIN annetuse_toiduained at ON a.id = at.annetus_id
        JOIN toiduained t ON at.toiduaine_id = t.id
        LEFT JOIN transpordid_annetused ta ON a.id = ta.annetus_id
        WHERE ta.transport_id IS NULL
    ) AS combined
    ORDER BY "annetuse number", kirjeldus;
END;
$$;


--
-- TOC entry 240 (class 1255 OID 90456)
-- Name: uuenda_annetuse_staatust(bigint, character varying); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.uuenda_annetuse_staatust(IN p_annetus_id bigint, IN p_uus_staatus character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE annetused
	SET staatus = p_uus_staatus
	WHERE id = p_annetus_id;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 223 (class 1259 OID 90297)
-- Name: aadressid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aadressid (
    id integer NOT NULL,
    tanav character varying(255) NOT NULL,
    maja character varying(255) NOT NULL,
    linn character varying(255) NOT NULL,
    postiindeks bigint NOT NULL
);


--
-- TOC entry 222 (class 1259 OID 90296)
-- Name: Aadressid_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Aadressid_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4978 (class 0 OID 0)
-- Dependencies: 222
-- Name: Aadressid_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Aadressid_ID_seq" OWNED BY public.aadressid.id;


--
-- TOC entry 231 (class 1259 OID 90333)
-- Name: annetuse_toiduained; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.annetuse_toiduained (
    id integer NOT NULL,
    annetus_id bigint NOT NULL,
    toiduaine_id bigint NOT NULL,
    kogus bigint NOT NULL,
    sailivusaeg date NOT NULL
);


--
-- TOC entry 230 (class 1259 OID 90332)
-- Name: Annetuse_toiduained_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Annetuse_toiduained_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4979 (class 0 OID 0)
-- Dependencies: 230
-- Name: Annetuse_toiduained_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Annetuse_toiduained_ID_seq" OWNED BY public.annetuse_toiduained.id;


--
-- TOC entry 229 (class 1259 OID 90324)
-- Name: annetused; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.annetused (
    id integer NOT NULL,
    kasutaja_id bigint NOT NULL,
    transport_id bigint,
    kirjeldus character varying(255) NOT NULL,
    annetuse_kuupaev date NOT NULL,
    staatus character varying(255) NOT NULL
);


--
-- TOC entry 228 (class 1259 OID 90323)
-- Name: Annetused_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Annetused_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4980 (class 0 OID 0)
-- Dependencies: 228
-- Name: Annetused_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Annetused_ID_seq" OWNED BY public.annetused.id;


--
-- TOC entry 225 (class 1259 OID 90306)
-- Name: kasutajad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kasutajad (
    id integer NOT NULL,
    ettevotte_nimi character varying(255),
    kontaktisik character varying(255) NOT NULL,
    "e-post" character varying(255),
    telefoninumber character varying(255),
    roll bigint NOT NULL,
    loomisaeg timestamp with time zone NOT NULL,
    staatus bigint NOT NULL,
    aadress_id bigint NOT NULL,
    "AVT_tuup" character varying(255) NOT NULL
);


--
-- TOC entry 224 (class 1259 OID 90305)
-- Name: Kasutajad_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Kasutajad_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4981 (class 0 OID 0)
-- Dependencies: 224
-- Name: Kasutajad_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Kasutajad_ID_seq" OWNED BY public.kasutajad.id;


--
-- TOC entry 220 (class 1259 OID 90285)
-- Name: toiduained; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.toiduained (
    id integer NOT NULL,
    nimetus character varying(255) NOT NULL,
    kategooria_id bigint NOT NULL
);


--
-- TOC entry 219 (class 1259 OID 90284)
-- Name: Toiduained_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Toiduained_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4982 (class 0 OID 0)
-- Dependencies: 219
-- Name: Toiduained_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Toiduained_ID_seq" OWNED BY public.toiduained.id;


--
-- TOC entry 218 (class 1259 OID 90278)
-- Name: toidukategooriad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.toidukategooriad (
    id integer NOT NULL,
    kategooria character varying(255) NOT NULL
);


--
-- TOC entry 217 (class 1259 OID 90277)
-- Name: Toidukategooriad_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Toidukategooriad_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4983 (class 0 OID 0)
-- Dependencies: 217
-- Name: Toidukategooriad_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Toidukategooriad_ID_seq" OWNED BY public.toidukategooriad.id;


--
-- TOC entry 235 (class 1259 OID 90347)
-- Name: transpordi_marsruudid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transpordi_marsruudid (
    id integer NOT NULL,
    transport_id bigint NOT NULL,
    alguskoht_aadress_id bigint NOT NULL,
    sihtkoht_aadress_id bigint NOT NULL
);


--
-- TOC entry 234 (class 1259 OID 90346)
-- Name: Transpordi_marsruudid_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Transpordi_marsruudid_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4984 (class 0 OID 0)
-- Dependencies: 234
-- Name: Transpordi_marsruudid_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Transpordi_marsruudid_ID_seq" OWNED BY public.transpordi_marsruudid.id;


--
-- TOC entry 227 (class 1259 OID 90315)
-- Name: transpordid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transpordid (
    id integer NOT NULL,
    kohaletoimetaja_id bigint NOT NULL,
    transpordivahend character varying(255) NOT NULL,
    transpordi_kuupaev date NOT NULL,
    staatus character varying(255) NOT NULL
);


--
-- TOC entry 226 (class 1259 OID 90314)
-- Name: Transpordid_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Transpordid_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4985 (class 0 OID 0)
-- Dependencies: 226
-- Name: Transpordid_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Transpordid_ID_seq" OWNED BY public.transpordid.id;


--
-- TOC entry 233 (class 1259 OID 90340)
-- Name: transpordid_annetused; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transpordid_annetused (
    id integer NOT NULL,
    annetus_id bigint NOT NULL,
    transport_id bigint NOT NULL
);


--
-- TOC entry 232 (class 1259 OID 90339)
-- Name: Transpordid_annetused_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Transpordid_annetused_ID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4986 (class 0 OID 0)
-- Dependencies: 232
-- Name: Transpordid_annetused_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Transpordid_annetused_ID_seq" OWNED BY public.transpordid_annetused.id;


--
-- TOC entry 238 (class 1259 OID 90451)
-- Name: aktiivseimad_annetajad; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.aktiivseimad_annetajad AS
SELECT
    NULL::character varying(255) AS kontaktisik,
    NULL::character varying(255) AS ettevotte_nimi,
    NULL::bigint AS "annetuste arv";


--
-- TOC entry 237 (class 1259 OID 90447)
-- Name: annetuste_sailivusajad; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.annetuste_sailivusajad AS
 SELECT annetuse_toiduained.annetus_id,
    toiduained.nimetus,
    annetuse_toiduained.kogus,
    annetuse_toiduained.sailivusaeg,
    (annetuse_toiduained.sailivusaeg - CURRENT_DATE) AS "päevi järgi"
   FROM (public.annetuse_toiduained
     JOIN public.toiduained ON ((annetuse_toiduained.toiduaine_id = toiduained.id)));


--
-- TOC entry 236 (class 1259 OID 90433)
-- Name: enim_annetatud_toiduained; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.enim_annetatud_toiduained AS
 SELECT toiduained.nimetus,
    toidukategooriad.kategooria,
    sum(annetuse_toiduained.kogus) AS kogus_kokku
   FROM ((public.annetuse_toiduained
     JOIN public.toiduained ON ((annetuse_toiduained.toiduaine_id = toiduained.id)))
     JOIN public.toidukategooriad ON ((toiduained.kategooria_id = toidukategooriad.id)))
  GROUP BY toiduained.nimetus, toidukategooriad.kategooria
  ORDER BY (sum(annetuse_toiduained.kogus)) DESC;


--
-- TOC entry 239 (class 1259 OID 90496)
-- Name: kuine_annetuste_statistika; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.kuine_annetuste_statistika AS
 SELECT date_trunc('month'::text, (a.annetuse_kuupaev)::timestamp with time zone) AS kuu,
    k.kategooria,
    count(DISTINCT a.id) AS "annetuste arv",
    sum(at.kogus) AS "toiduainete koguarv",
    count(DISTINCT a.kasutaja_id) AS "aktiivseid annetajaid"
   FROM (((public.annetused a
     JOIN public.annetuse_toiduained at ON ((a.id = at.annetus_id)))
     JOIN public.toiduained t ON ((at.toiduaine_id = t.id)))
     JOIN public.toidukategooriad k ON ((t.kategooria_id = k.id)))
  GROUP BY (date_trunc('month'::text, (a.annetuse_kuupaev)::timestamp with time zone)), k.kategooria
  ORDER BY (date_trunc('month'::text, (a.annetuse_kuupaev)::timestamp with time zone)) DESC, k.kategooria;


--
-- TOC entry 221 (class 1259 OID 90291)
-- Name: postiindeksid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.postiindeksid (
    id bigint NOT NULL,
    haldusuksus character varying(255) NOT NULL
);


--
-- TOC entry 4763 (class 2604 OID 90300)
-- Name: aadressid id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aadressid ALTER COLUMN id SET DEFAULT nextval('public."Aadressid_ID_seq"'::regclass);


--
-- TOC entry 4767 (class 2604 OID 90336)
-- Name: annetuse_toiduained id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annetuse_toiduained ALTER COLUMN id SET DEFAULT nextval('public."Annetuse_toiduained_ID_seq"'::regclass);


--
-- TOC entry 4766 (class 2604 OID 90327)
-- Name: annetused id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annetused ALTER COLUMN id SET DEFAULT nextval('public."Annetused_ID_seq"'::regclass);


--
-- TOC entry 4764 (class 2604 OID 90309)
-- Name: kasutajad id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kasutajad ALTER COLUMN id SET DEFAULT nextval('public."Kasutajad_ID_seq"'::regclass);


--
-- TOC entry 4762 (class 2604 OID 90288)
-- Name: toiduained id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toiduained ALTER COLUMN id SET DEFAULT nextval('public."Toiduained_ID_seq"'::regclass);


--
-- TOC entry 4761 (class 2604 OID 90281)
-- Name: toidukategooriad id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toidukategooriad ALTER COLUMN id SET DEFAULT nextval('public."Toidukategooriad_ID_seq"'::regclass);


--
-- TOC entry 4769 (class 2604 OID 90350)
-- Name: transpordi_marsruudid id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordi_marsruudid ALTER COLUMN id SET DEFAULT nextval('public."Transpordi_marsruudid_ID_seq"'::regclass);


--
-- TOC entry 4765 (class 2604 OID 90318)
-- Name: transpordid id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordid ALTER COLUMN id SET DEFAULT nextval('public."Transpordid_ID_seq"'::regclass);


--
-- TOC entry 4768 (class 2604 OID 90343)
-- Name: transpordid_annetused id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordid_annetused ALTER COLUMN id SET DEFAULT nextval('public."Transpordid_annetused_ID_seq"'::regclass);


--
-- TOC entry 4959 (class 0 OID 90297)
-- Dependencies: 223
-- Data for Name: aadressid; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.aadressid VALUES (1, 'Viru', '10', 'Tallinn', 10123);
INSERT INTO public.aadressid VALUES (2, 'Küüni', '5A', 'Tartu', 20234);
INSERT INTO public.aadressid VALUES (3, 'Rüütli', '12', 'Pärnu', 30345);
INSERT INTO public.aadressid VALUES (4, 'Pushkini', '7', 'Narva', 40456);
INSERT INTO public.aadressid VALUES (5, 'Tallinna', '3', 'Viljandi', 50567);


--
-- TOC entry 4967 (class 0 OID 90333)
-- Dependencies: 231
-- Data for Name: annetuse_toiduained; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.annetuse_toiduained VALUES (1, 1, 1, 10, '2025-05-20');
INSERT INTO public.annetuse_toiduained VALUES (2, 1, 2, 5, '2025-05-18');
INSERT INTO public.annetuse_toiduained VALUES (3, 2, 3, 15, '2025-06-01');
INSERT INTO public.annetuse_toiduained VALUES (4, 2, 4, 7, '2025-05-25');
INSERT INTO public.annetuse_toiduained VALUES (5, 3, 1, 12, '2025-05-30');
INSERT INTO public.annetuse_toiduained VALUES (12, 10, 4, 8, '2025-05-10');
INSERT INTO public.annetuse_toiduained VALUES (13, 10, 5, 12, '2025-05-08');
INSERT INTO public.annetuse_toiduained VALUES (14, 10, 4, 6, '2025-05-12');


--
-- TOC entry 4965 (class 0 OID 90324)
-- Dependencies: 229
-- Data for Name: annetused; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.annetused VALUES (2, 2, 2, 'piimatooted', '2025-04-29', 'töös');
INSERT INTO public.annetused VALUES (3, 3, 3, 'liha', '2025-04-30', 'lõpetatud');
INSERT INTO public.annetused VALUES (4, 4, 4, 'leivad', '2025-05-01', 'uus');
INSERT INTO public.annetused VALUES (5, 5, 5, 'maiustused', '2025-05-02', 'tühistatud');
INSERT INTO public.annetused VALUES (10, 3, NULL, 'Restorani ülejäägid: supid ja salatid', '2025-05-05', 'aktiivne');
INSERT INTO public.annetused VALUES (1, 1, 1, 'puu- ja juurviljad', '2025-04-28', 'kohale toimetatud');


--
-- TOC entry 4961 (class 0 OID 90306)
-- Dependencies: 225
-- Data for Name: kasutajad; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.kasutajad VALUES (1, 'Toidupank', 'Mari Maasikas', 'mari@mingimeil.com', '51234567', 1, '2025-05-04 16:52:02.226388+03', 1, 1, 'MTÜ');
INSERT INTO public.kasutajad VALUES (2, 'Hea Süda OÜ', 'Jüri Juurikas', 'jyri@mingimeil.com', '53456789', 2, '2025-05-04 16:52:02.226388+03', 1, 2, 'Ettevõte');
INSERT INTO public.kasutajad VALUES (3, NULL, 'Laura Leht', NULL, NULL, 1, '2025-05-04 16:52:02.226388+03', 1, 3, 'Eraklient');
INSERT INTO public.kasutajad VALUES (4, 'Abikäsi', 'Peeter Pähkel', 'peeter@mingimeil.com', '5551234', 1, '2025-05-04 16:52:02.226388+03', 1, 4, 'MTÜ');
INSERT INTO public.kasutajad VALUES (5, 'Toiduabi AS', 'Katrin Kartul', 'katrin@mingimeil.com', '56677889', 2, '2025-05-04 16:52:02.226388+03', 1, 5, 'Ettevõte');


--
-- TOC entry 4957 (class 0 OID 90291)
-- Dependencies: 221
-- Data for Name: postiindeksid; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.postiindeksid VALUES (10123, 'Tallinn');
INSERT INTO public.postiindeksid VALUES (20234, 'Tartu');
INSERT INTO public.postiindeksid VALUES (30345, 'Pärnu');
INSERT INTO public.postiindeksid VALUES (40456, 'Narva');
INSERT INTO public.postiindeksid VALUES (50567, 'Viljandi');


--
-- TOC entry 4956 (class 0 OID 90285)
-- Dependencies: 220
-- Data for Name: toiduained; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.toiduained VALUES (1, 'õun', 1);
INSERT INTO public.toiduained VALUES (2, 'piim', 2);
INSERT INTO public.toiduained VALUES (3, 'sealiha', 3);
INSERT INTO public.toiduained VALUES (4, 'leib', 4);
INSERT INTO public.toiduained VALUES (5, 'šokolaad', 5);


--
-- TOC entry 4954 (class 0 OID 90278)
-- Dependencies: 218
-- Data for Name: toidukategooriad; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.toidukategooriad VALUES (1, 'puu- ja köögiviljad');
INSERT INTO public.toidukategooriad VALUES (2, 'piimatooted');
INSERT INTO public.toidukategooriad VALUES (3, 'liha');
INSERT INTO public.toidukategooriad VALUES (4, 'teraviljatooted');
INSERT INTO public.toidukategooriad VALUES (5, 'maiustused');


--
-- TOC entry 4971 (class 0 OID 90347)
-- Dependencies: 235
-- Data for Name: transpordi_marsruudid; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.transpordi_marsruudid VALUES (1, 1, 1, 2);
INSERT INTO public.transpordi_marsruudid VALUES (2, 2, 2, 3);
INSERT INTO public.transpordi_marsruudid VALUES (3, 3, 3, 4);
INSERT INTO public.transpordi_marsruudid VALUES (4, 4, 4, 5);
INSERT INTO public.transpordi_marsruudid VALUES (5, 5, 5, 1);


--
-- TOC entry 4963 (class 0 OID 90315)
-- Dependencies: 227
-- Data for Name: transpordid; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.transpordid VALUES (1, 1, 'kaubik', '2025-05-01', 'planeeritud');
INSERT INTO public.transpordid VALUES (2, 2, 'veok', '2025-05-02', 'teel');
INSERT INTO public.transpordid VALUES (3, 3, 'auto', '2025-05-03', 'teostatud');
INSERT INTO public.transpordid VALUES (4, 4, 'kaubik', '2025-05-04', 'planeeritud');
INSERT INTO public.transpordid VALUES (5, 5, 'veok', '2025-05-05', 'tühistatud');


--
-- TOC entry 4969 (class 0 OID 90340)
-- Dependencies: 233
-- Data for Name: transpordid_annetused; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.transpordid_annetused VALUES (1, 1, 1);
INSERT INTO public.transpordid_annetused VALUES (2, 2, 2);
INSERT INTO public.transpordid_annetused VALUES (3, 3, 3);
INSERT INTO public.transpordid_annetused VALUES (4, 4, 4);
INSERT INTO public.transpordid_annetused VALUES (5, 5, 5);


--
-- TOC entry 4987 (class 0 OID 0)
-- Dependencies: 222
-- Name: Aadressid_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Aadressid_ID_seq"', 5, true);


--
-- TOC entry 4988 (class 0 OID 0)
-- Dependencies: 230
-- Name: Annetuse_toiduained_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Annetuse_toiduained_ID_seq"', 14, true);


--
-- TOC entry 4989 (class 0 OID 0)
-- Dependencies: 228
-- Name: Annetused_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Annetused_ID_seq"', 10, true);


--
-- TOC entry 4990 (class 0 OID 0)
-- Dependencies: 224
-- Name: Kasutajad_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Kasutajad_ID_seq"', 5, true);


--
-- TOC entry 4991 (class 0 OID 0)
-- Dependencies: 219
-- Name: Toiduained_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Toiduained_ID_seq"', 5, true);


--
-- TOC entry 4992 (class 0 OID 0)
-- Dependencies: 217
-- Name: Toidukategooriad_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Toidukategooriad_ID_seq"', 5, true);


--
-- TOC entry 4993 (class 0 OID 0)
-- Dependencies: 234
-- Name: Transpordi_marsruudid_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Transpordi_marsruudid_ID_seq"', 5, true);


--
-- TOC entry 4994 (class 0 OID 0)
-- Dependencies: 226
-- Name: Transpordid_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Transpordid_ID_seq"', 5, true);


--
-- TOC entry 4995 (class 0 OID 0)
-- Dependencies: 232
-- Name: Transpordid_annetused_ID_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Transpordid_annetused_ID_seq"', 5, true);


--
-- TOC entry 4777 (class 2606 OID 90304)
-- Name: aadressid Aadressid_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aadressid
    ADD CONSTRAINT "Aadressid_pkey" PRIMARY KEY (id);


--
-- TOC entry 4785 (class 2606 OID 90338)
-- Name: annetuse_toiduained Annetuse_toiduained_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annetuse_toiduained
    ADD CONSTRAINT "Annetuse_toiduained_pkey" PRIMARY KEY (id);


--
-- TOC entry 4783 (class 2606 OID 90331)
-- Name: annetused Annetused_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annetused
    ADD CONSTRAINT "Annetused_pkey" PRIMARY KEY (id);


--
-- TOC entry 4779 (class 2606 OID 90313)
-- Name: kasutajad Kasutajad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kasutajad
    ADD CONSTRAINT "Kasutajad_pkey" PRIMARY KEY (id);


--
-- TOC entry 4775 (class 2606 OID 90295)
-- Name: postiindeksid Postiindeksid_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postiindeksid
    ADD CONSTRAINT "Postiindeksid_pkey" PRIMARY KEY (id);


--
-- TOC entry 4773 (class 2606 OID 90290)
-- Name: toiduained Toiduained_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toiduained
    ADD CONSTRAINT "Toiduained_pkey" PRIMARY KEY (id);


--
-- TOC entry 4771 (class 2606 OID 90283)
-- Name: toidukategooriad Toidukategooriad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toidukategooriad
    ADD CONSTRAINT "Toidukategooriad_pkey" PRIMARY KEY (id);


--
-- TOC entry 4789 (class 2606 OID 90352)
-- Name: transpordi_marsruudid Transpordi_marsruudid_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordi_marsruudid
    ADD CONSTRAINT "Transpordi_marsruudid_pkey" PRIMARY KEY (id);


--
-- TOC entry 4787 (class 2606 OID 90345)
-- Name: transpordid_annetused Transpordid_annetused_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordid_annetused
    ADD CONSTRAINT "Transpordid_annetused_pkey" PRIMARY KEY (id);


--
-- TOC entry 4781 (class 2606 OID 90322)
-- Name: transpordid Transpordid_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordid
    ADD CONSTRAINT "Transpordid_pkey" PRIMARY KEY (id);


--
-- TOC entry 4951 (class 2618 OID 90454)
-- Name: aktiivseimad_annetajad _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.aktiivseimad_annetajad AS
 SELECT kasutajad.kontaktisik,
    kasutajad.ettevotte_nimi,
    count(annetused.id) AS "annetuste arv"
   FROM (public.kasutajad
     JOIN public.annetused ON ((kasutajad.id = annetused.kasutaja_id)))
  GROUP BY kasutajad.id
  ORDER BY (count(annetused.id)) DESC;


--
-- TOC entry 4803 (class 2620 OID 90488)
-- Name: annetuse_toiduained toiduaine_eksisteerib; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER toiduaine_eksisteerib BEFORE INSERT ON public.annetuse_toiduained FOR EACH ROW EXECUTE FUNCTION public.kas_toiduaine_eksisteerib();


--
-- TOC entry 4791 (class 2606 OID 90428)
-- Name: aadressid Aadressid_fk_postiindeks; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aadressid
    ADD CONSTRAINT "Aadressid_fk_postiindeks" FOREIGN KEY (postiindeks) REFERENCES public.postiindeksid(id);


--
-- TOC entry 4796 (class 2606 OID 90383)
-- Name: annetuse_toiduained Annetuse_toiduained_fk1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annetuse_toiduained
    ADD CONSTRAINT "Annetuse_toiduained_fk1" FOREIGN KEY (annetus_id) REFERENCES public.annetused(id);


--
-- TOC entry 4797 (class 2606 OID 90388)
-- Name: annetuse_toiduained Annetuse_toiduained_fk2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annetuse_toiduained
    ADD CONSTRAINT "Annetuse_toiduained_fk2" FOREIGN KEY (toiduaine_id) REFERENCES public.toiduained(id);


--
-- TOC entry 4794 (class 2606 OID 90373)
-- Name: annetused Annetused_fk1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annetused
    ADD CONSTRAINT "Annetused_fk1" FOREIGN KEY (kasutaja_id) REFERENCES public.kasutajad(id);


--
-- TOC entry 4795 (class 2606 OID 90378)
-- Name: annetused Annetused_fk2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annetused
    ADD CONSTRAINT "Annetused_fk2" FOREIGN KEY (transport_id) REFERENCES public.transpordid(id);


--
-- TOC entry 4792 (class 2606 OID 90363)
-- Name: kasutajad Kasutajad_fk8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kasutajad
    ADD CONSTRAINT "Kasutajad_fk8" FOREIGN KEY (aadress_id) REFERENCES public.aadressid(id);


--
-- TOC entry 4790 (class 2606 OID 90353)
-- Name: toiduained Toiduained_fk2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.toiduained
    ADD CONSTRAINT "Toiduained_fk2" FOREIGN KEY (kategooria_id) REFERENCES public.toidukategooriad(id);


--
-- TOC entry 4800 (class 2606 OID 90403)
-- Name: transpordi_marsruudid Transpordi_marsruudid_fk1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordi_marsruudid
    ADD CONSTRAINT "Transpordi_marsruudid_fk1" FOREIGN KEY (transport_id) REFERENCES public.transpordid(id);


--
-- TOC entry 4801 (class 2606 OID 90408)
-- Name: transpordi_marsruudid Transpordi_marsruudid_fk2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordi_marsruudid
    ADD CONSTRAINT "Transpordi_marsruudid_fk2" FOREIGN KEY (alguskoht_aadress_id) REFERENCES public.aadressid(id);


--
-- TOC entry 4802 (class 2606 OID 90413)
-- Name: transpordi_marsruudid Transpordi_marsruudid_fk3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordi_marsruudid
    ADD CONSTRAINT "Transpordi_marsruudid_fk3" FOREIGN KEY (sihtkoht_aadress_id) REFERENCES public.aadressid(id);


--
-- TOC entry 4798 (class 2606 OID 90393)
-- Name: transpordid_annetused Transpordid_annetused_fk1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordid_annetused
    ADD CONSTRAINT "Transpordid_annetused_fk1" FOREIGN KEY (annetus_id) REFERENCES public.annetused(id);


--
-- TOC entry 4799 (class 2606 OID 90398)
-- Name: transpordid_annetused Transpordid_annetused_fk2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordid_annetused
    ADD CONSTRAINT "Transpordid_annetused_fk2" FOREIGN KEY (transport_id) REFERENCES public.transpordid(id);


--
-- TOC entry 4793 (class 2606 OID 90368)
-- Name: transpordid Transpordid_fk1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transpordid
    ADD CONSTRAINT "Transpordid_fk1" FOREIGN KEY (kohaletoimetaja_id) REFERENCES public.kasutajad(id);


-- Completed on 2025-05-06 00:53:44

--
-- PostgreSQL database dump complete
--

