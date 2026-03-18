--
-- PostgreSQL database dump
--


-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: kanji; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kanji (
    id uuid NOT NULL,
    "character" character varying(255) NOT NULL,
    meanings character varying(255)[] NOT NULL,
    stroke_count integer NOT NULL,
    jlpt_level integer NOT NULL,
    stroke_data jsonb DEFAULT '{}'::jsonb,
    radicals character varying(255)[] DEFAULT ARRAY[]::character varying[],
    frequency integer,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    translations jsonb DEFAULT '{}'::jsonb
);


--
-- Name: kanji_readings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kanji_readings (
    id uuid NOT NULL,
    reading_type character varying(255) NOT NULL,
    reading character varying(255) NOT NULL,
    romaji character varying(255) NOT NULL,
    usage_notes text,
    kanji_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: lesson_kanjis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lesson_kanjis (
    id uuid NOT NULL,
    "position" integer NOT NULL,
    lesson_id uuid NOT NULL,
    kanji_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: lesson_words; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lesson_words (
    id uuid NOT NULL,
    "position" integer NOT NULL,
    lesson_id uuid NOT NULL,
    word_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: lessons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lessons (
    id uuid NOT NULL,
    title character varying(255) NOT NULL,
    description text NOT NULL,
    difficulty integer NOT NULL,
    order_index integer NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    lesson_type public.lesson_type DEFAULT 'reading'::public.lesson_type NOT NULL,
    test_id uuid,
    translations jsonb DEFAULT '{}'::jsonb
);


--
-- Name: word_kanjis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.word_kanjis (
    id uuid NOT NULL,
    "position" integer NOT NULL,
    word_id uuid NOT NULL,
    kanji_id uuid NOT NULL,
    kanji_reading_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: words; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.words (
    id uuid NOT NULL,
    text character varying(255) NOT NULL,
    meaning character varying(255) NOT NULL,
    reading character varying(255) NOT NULL,
    difficulty integer NOT NULL,
    usage_frequency integer DEFAULT 1000,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    word_type public.word_type DEFAULT 'other'::public.word_type NOT NULL,
    sort_score integer,
    core_rank integer,
    example_sentence text,
    example_reading text,
    example_meaning text,
    translations jsonb DEFAULT '{}'::jsonb
);


--
-- Name: kanji kanji_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kanji
    ADD CONSTRAINT kanji_pkey PRIMARY KEY (id);


--
-- Name: kanji_readings kanji_readings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kanji_readings
    ADD CONSTRAINT kanji_readings_pkey PRIMARY KEY (id);


--
-- Name: lesson_kanjis lesson_kanjis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_kanjis
    ADD CONSTRAINT lesson_kanjis_pkey PRIMARY KEY (id);


--
-- Name: lesson_words lesson_words_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_words
    ADD CONSTRAINT lesson_words_pkey PRIMARY KEY (id);


--
-- Name: lessons lessons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT lessons_pkey PRIMARY KEY (id);


--
-- Name: word_kanjis word_kanjis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.word_kanjis
    ADD CONSTRAINT word_kanjis_pkey PRIMARY KEY (id);


--
-- Name: words words_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.words
    ADD CONSTRAINT words_pkey PRIMARY KEY (id);


--
-- Name: kanji_character_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX kanji_character_index ON public.kanji USING btree ("character");


--
-- Name: kanji_frequency_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX kanji_frequency_index ON public.kanji USING btree (frequency);


--
-- Name: kanji_jlpt_level_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX kanji_jlpt_level_index ON public.kanji USING btree (jlpt_level);


--
-- Name: kanji_readings_kanji_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX kanji_readings_kanji_id_index ON public.kanji_readings USING btree (kanji_id);


--
-- Name: kanji_readings_reading_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX kanji_readings_reading_type_index ON public.kanji_readings USING btree (reading_type);


--
-- Name: kanji_translations_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX kanji_translations_index ON public.kanji USING gin (translations);


--
-- Name: lesson_kanjis_kanji_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lesson_kanjis_kanji_id_index ON public.lesson_kanjis USING btree (kanji_id);


--
-- Name: lesson_kanjis_lesson_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lesson_kanjis_lesson_id_index ON public.lesson_kanjis USING btree (lesson_id);


--
-- Name: lesson_kanjis_lesson_id_kanji_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX lesson_kanjis_lesson_id_kanji_id_index ON public.lesson_kanjis USING btree (lesson_id, kanji_id);


--
-- Name: lesson_kanjis_lesson_id_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX lesson_kanjis_lesson_id_position_index ON public.lesson_kanjis USING btree (lesson_id, "position");


--
-- Name: lesson_words_lesson_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lesson_words_lesson_id_index ON public.lesson_words USING btree (lesson_id);


--
-- Name: lesson_words_lesson_id_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX lesson_words_lesson_id_position_index ON public.lesson_words USING btree (lesson_id, "position");


--
-- Name: lesson_words_lesson_id_word_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX lesson_words_lesson_id_word_id_index ON public.lesson_words USING btree (lesson_id, word_id);


--
-- Name: lesson_words_word_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lesson_words_word_id_index ON public.lesson_words USING btree (word_id);


--
-- Name: lessons_difficulty_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lessons_difficulty_index ON public.lessons USING btree (difficulty);


--
-- Name: lessons_difficulty_order_index_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX lessons_difficulty_order_index_index ON public.lessons USING btree (difficulty, order_index);


--
-- Name: lessons_lesson_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lessons_lesson_type_index ON public.lessons USING btree (lesson_type);


--
-- Name: lessons_order_index_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lessons_order_index_index ON public.lessons USING btree (order_index);


--
-- Name: lessons_test_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lessons_test_id_index ON public.lessons USING btree (test_id);


--
-- Name: lessons_translations_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lessons_translations_index ON public.lessons USING gin (translations);


--
-- Name: word_kanjis_kanji_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX word_kanjis_kanji_id_index ON public.word_kanjis USING btree (kanji_id);


--
-- Name: word_kanjis_kanji_reading_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX word_kanjis_kanji_reading_id_index ON public.word_kanjis USING btree (kanji_reading_id);


--
-- Name: word_kanjis_word_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX word_kanjis_word_id_index ON public.word_kanjis USING btree (word_id);


--
-- Name: word_kanjis_word_id_kanji_id_position_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX word_kanjis_word_id_kanji_id_position_index ON public.word_kanjis USING btree (word_id, kanji_id, "position");


--
-- Name: words_core_rank_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_core_rank_index ON public.words USING btree (core_rank);


--
-- Name: words_difficulty_core_rank_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_difficulty_core_rank_index ON public.words USING btree (difficulty, core_rank);


--
-- Name: words_difficulty_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_difficulty_index ON public.words USING btree (difficulty);


--
-- Name: words_difficulty_sort_score_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_difficulty_sort_score_index ON public.words USING btree (difficulty, sort_score);


--
-- Name: words_text_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX words_text_index ON public.words USING btree (text);


--
-- Name: words_translations_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_translations_index ON public.words USING gin (translations);


--
-- Name: words_usage_frequency_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_usage_frequency_index ON public.words USING btree (usage_frequency);


--
-- Name: words_word_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX words_word_type_index ON public.words USING btree (word_type);


--
-- Name: kanji_readings kanji_readings_kanji_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kanji_readings
    ADD CONSTRAINT kanji_readings_kanji_id_fkey FOREIGN KEY (kanji_id) REFERENCES public.kanji(id) ON DELETE CASCADE;


--
-- Name: lesson_kanjis lesson_kanjis_kanji_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_kanjis
    ADD CONSTRAINT lesson_kanjis_kanji_id_fkey FOREIGN KEY (kanji_id) REFERENCES public.kanji(id) ON DELETE CASCADE;


--
-- Name: lesson_kanjis lesson_kanjis_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_kanjis
    ADD CONSTRAINT lesson_kanjis_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE CASCADE;


--
-- Name: lesson_words lesson_words_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_words
    ADD CONSTRAINT lesson_words_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE CASCADE;


--
-- Name: lesson_words lesson_words_word_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_words
    ADD CONSTRAINT lesson_words_word_id_fkey FOREIGN KEY (word_id) REFERENCES public.words(id) ON DELETE CASCADE;


--
-- Name: lessons lessons_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT lessons_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.tests(id) ON DELETE SET NULL;


--
-- Name: word_kanjis word_kanjis_kanji_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.word_kanjis
    ADD CONSTRAINT word_kanjis_kanji_id_fkey FOREIGN KEY (kanji_id) REFERENCES public.kanji(id) ON DELETE CASCADE;


--
-- Name: word_kanjis word_kanjis_kanji_reading_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.word_kanjis
    ADD CONSTRAINT word_kanjis_kanji_reading_id_fkey FOREIGN KEY (kanji_reading_id) REFERENCES public.kanji_readings(id) ON DELETE SET NULL;


--
-- Name: word_kanjis word_kanjis_word_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.word_kanjis
    ADD CONSTRAINT word_kanjis_word_id_fkey FOREIGN KEY (word_id) REFERENCES public.words(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--


