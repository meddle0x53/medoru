--
-- PostgreSQL database dump
--

\restrict mVOlyPDFbZroAu7cATahe34jmkOcOBFvzCtSTJE5IHloE3aACZJ3kTY8eo1rkxH

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
-- PostgreSQL database dump complete
--

\unrestrict mVOlyPDFbZroAu7cATahe34jmkOcOBFvzCtSTJE5IHloE3aACZJ3kTY8eo1rkxH

