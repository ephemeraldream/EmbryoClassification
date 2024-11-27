#!/bin/bash

# Путь к основной базе данных
MAIN_DB="so_deep.db"

# Проверка, существует ли основная база данных
if [ ! -f "$MAIN_DB" ]; then
    echo "Создание основной базы данных $MAIN_DB..."
    sqlite3 $MAIN_DB <<EOF
    PRAGMA foreign_keys = ON;

    -- Создание таблицы cycle_type
    CREATE TABLE cycle_type
    (
        ct_id smallint NOT NULL,
        ct_tname character varying(8) NOT NULL,
        CONSTRAINT cycle_type_pk PRIMARY KEY (ct_id)
    );

    -- Создание таблицы pair_table
    CREATE TABLE pair_table
    (
        pr_id uuid NOT NULL,
        pr_idf uuid NOT NULL,
        pr_idm uuid NOT NULL,
        pt_infertilitytype boolean,
        pt_bdatem date NOT NULL,
        pt_bdatef date NOT NULL,
        CONSTRAINT pair_table_pk PRIMARY KEY (pr_id)
    );

    -- Создание таблицы marker_tree
    CREATE TABLE marker_tree
    (
        mt_id integer NOT NULL,
        mt_parent integer DEFAULT 0,
        mt_primary boolean DEFAULT true,
        mt_stored_data text,
        mt_marker_type integer,
        mt_ins_from decimal(6,2),
        mt_ins_to decimal(6,2),
        mt_stored_data_short text,
        mt_label character varying(10),
        CONSTRAINT marker_tree_pkey PRIMARY KEY (mt_id)
    );

    -- Создание таблицы embryo_data
    CREATE TABLE embryo_data
    (
        ed_uuid uuid NOT NULL,
        ed_pr_id uuid NOT NULL,
        ed_id smallint NOT NULL,
        ed_cs_id uuid NOT NULL,
        ed_destiny character(4) NOT NULL,
        ed_mainfocus smallint DEFAULT 0,
        ed_focus_min smallint,
        ed_focus_max smallint,
        ed_own boolean DEFAULT true,
        ed_fresh boolean DEFAULT true,
        ed_biodate date,
        ed_fertilization smallint,
        ed_seriescount integer DEFAULT 0,
        ed_pn_size_rate character varying(6),
        ed_insemination timestamp without time zone,
        ed_iceps boolean DEFAULT false,
        ed_icinc boolean DEFAULT false,
        ed_anom_form boolean DEFAULT false,
        ed_cl2_sz boolean DEFAULT false,
        ed_cl3_sz boolean DEFAULT false,
        ed_cl4_sz boolean DEFAULT false,
        ed_cl5_sz boolean DEFAULT false,
        ed_cl6_sz boolean DEFAULT false,
        ed_cl8_sz boolean DEFAULT false,
        ed_clrev boolean DEFAULT false,
        ed_mnb boolean DEFAULT false,
        ed_vacuolization boolean DEFAULT false,
        ed_frag integer,
        ed_ins_method smallint DEFAULT 1,
        ed_finalscore character varying(3),
        ed_pn_start_time decimal(6,2),
        ed_pn_ds_time decimal(6,2),
        ed_t2 decimal(6,2),
        ed_t3 decimal(6,2),
        ed_t4 decimal(6,2),
        ed_t5 decimal(6,2),
        ed_t6 decimal(6,2),
        ed_t8 decimal(6,2),
        ed_first_clvg_time decimal(6,2),
        ed_compact_start decimal(6,2),
        ed_compacted_time decimal(6,2),
        ed_cavitation_start decimal(6,2),
        ed_full_blast decimal(6,2),
        ed_expand_time decimal(6,2),
        ed_hatching_start decimal(6,2),
        et_etdt timestamp without time zone,
        et_cat uuid,
        et_frzdt timestamp without time zone,
        et_dscrdt timestamp without time zone,
        et_etwith uuid,
        et_hcgtest boolean DEFAULT false,
        et_cp boolean DEFAULT false,
        et_gstsacs integer DEFAULT 0,
        et_prresult integer,
        et_brthdate timestamp without time zone,
        et_nbqtty integer,
        et_nbweight integer,
        vcs_srvrserial character varying(255),
        vcs_scale real,
        CONSTRAINT et_data_pk PRIMARY KEY (ed_uuid)
    );

    -- Создание таблицы well_timeline
    CREATE TABLE well_timeline
    (
        wtl_id integer NOT NULL,
        wtl_ed_uuid uuid NOT NULL,
        wtl_focus smallint DEFAULT 0,
        wtl_tempr real NOT NULL,
        wtl_gas_co2 character varying NOT NULL,
        wtl_co2_concentration real,
        wtl_co2_flow real,
        wtl_frame_dt timestamp without time zone NOT NULL,
        CONSTRAINT well_tl_pk PRIMARY KEY (wtl_id, wtl_ed_uuid),
        CONSTRAINT embryo_data_well_timeline_fk FOREIGN KEY (wtl_ed_uuid)
            REFERENCES embryo_data (ed_uuid) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE CASCADE
    );

    -- Создание таблицы well_timeline_frames
    CREATE TABLE well_timeline_frames
    (
        wtf_wtl_id integer NOT NULL,
        wtf_ed_uuid uuid NOT NULL,
        wtf_rel_focus integer NOT NULL,
        wtf_frame blob NOT NULL,
        wtf_dif integer DEFAULT 0,
        wtf_stabilized boolean NOT NULL DEFAULT false,
        CONSTRAINT well_timeline_frames_pk PRIMARY KEY (wtf_wtl_id, wtf_ed_uuid, wtf_rel_focus),
        CONSTRAINT well_timeline_well_timeline_frames_fk FOREIGN KEY (wtf_ed_uuid, wtf_wtl_id)
            REFERENCES well_timeline (wtl_ed_uuid, wtl_id) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE CASCADE
    );

    -- Создание таблицы well_timeline_marker
    CREATE TABLE well_timeline_marker
    (
        wtm_wtl_id integer NOT NULL,
        wtm_focus smallint NOT NULL,
        wtm_ed_uuid uuid NOT NULL,
        wtm_mark_id integer NOT NULL,
        wtm_mark_data text,
        wtm_restrict_mark integer NOT NULL,
        CONSTRAINT well_timeline_marker_pkey PRIMARY KEY (wtm_wtl_id, wtm_focus, wtm_ed_uuid, wtm_mark_id)
    );

    -- Создание таблицы embryo_focus
    CREATE TABLE embryo_focus
    (
        ef_ed_uuid uuid NOT NULL,
        ef_focus smallint NOT NULL,
        ef_wtl_id integer NOT NULL,
        CONSTRAINT ef_pk PRIMARY KEY (ef_ed_uuid, ef_wtl_id),
        CONSTRAINT embryo_data_embryo_focus_fk FOREIGN KEY (ef_ed_uuid)
            REFERENCES embryo_data (ed_uuid) MATCH SIMPLE
            ON UPDATE CASCADE
            ON DELETE CASCADE
    );
EOF
    if [ $? -ne 0 ]; then
        echo "Ошибка при создании основной базы данных $MAIN_DB."
        exit 1
    fi
    echo "Основная база данных $MAIN_DB создана."
else
    echo "Основная база данных $MAIN_DB уже существует."
fi

# Перебор всех файлов .ev2 в текущей директории
for ev2_file in *.ev2; do
    # Проверка, существует ли файл
    if [ ! -f "$ev2_file" ]; then
        echo "Файл $ev2_file не найден, пропуск."
        continue
    fi

    echo "Обработка файла $ev2_file..."

    # Выполнение SQL-команд для объединения данных
    sqlite3 $MAIN_DB <<EOF
    PRAGMA foreign_keys = ON;
    ATTACH DATABASE '$ev2_file' AS source;

    -- Вставка данных в cycle_type
    INSERT OR IGNORE INTO cycle_type (ct_id, ct_tname)
    SELECT ct_id, ct_tname FROM source.cycle_type;

    -- Вставка данных в pair_table
    INSERT OR IGNORE INTO pair_table (pr_id, pr_idf, pr_idm, pt_infertilitytype, pt_bdatem, pt_bdatef)
    SELECT pr_id, pr_idf, pr_idm, pt_infertilitytype, pt_bdatem, pt_bdatef FROM source.pair_table;

    -- Вставка данных в marker_tree
    INSERT OR IGNORE INTO marker_tree (mt_id, mt_parent, mt_primary, mt_stored_data, mt_marker_type, mt_ins_from, mt_ins_to, mt_stored_data_short, mt_label)
    SELECT mt_id, mt_parent, mt_primary, mt_stored_data, mt_marker_type, mt_ins_from, mt_ins_to, mt_stored_data_short, mt_label FROM source.marker_tree;

    -- Вставка данных в embryo_data
    INSERT OR IGNORE INTO embryo_data (
        ed_uuid, ed_pr_id, ed_id, ed_cs_id, ed_destiny, ed_mainfocus, ed_focus_min, ed_focus_max, ed_own, ed_fresh,
        ed_biodate, ed_fertilization, ed_seriescount, ed_pn_size_rate, ed_insemination, ed_iceps, ed_icinc,
        ed_anom_form, ed_cl2_sz, ed_cl3_sz, ed_cl4_sz, ed_cl5_sz, ed_cl6_sz, ed_cl8_sz, ed_clrev, ed_mnb,
        ed_vacuolization, ed_frag, ed_ins_method, ed_finalscore, ed_pn_start_time, ed_pn_ds_time, ed_t2, ed_t3,
        ed_t4, ed_t5, ed_t6, ed_t8, ed_first_clvg_time, ed_compact_start, ed_compacted_time, ed_cavitation_start,
        ed_full_blast, ed_expand_time, ed_hatching_start, et_etdt, et_cat, et_frzdt, et_dscrdt, et_etwith,
        et_hcgtest, et_cp, et_gstsacs, et_prresult, et_brthdate, et_nbqtty, et_nbweight, vcs_srvrserial,
        vcs_scale
    )
    SELECT
        ed_uuid, ed_pr_id, ed_id, ed_cs_id, ed_destiny, ed_mainfocus, ed_focus_min, ed_focus_max, ed_own, ed_fresh,
        ed_biodate, ed_fertilization, ed_seriescount, ed_pn_size_rate, ed_insemination, ed_iceps, ed_icinc,
        ed_anom_form, ed_cl2_sz, ed_cl3_sz, ed_cl4_sz, ed_cl5_sz, ed_cl6_sz, ed_cl8_sz, ed_clrev, ed_mnb,
        ed_vacuolization, ed_frag, ed_ins_method, ed_finalscore, ed_pn_start_time, ed_pn_ds_time, ed_t2, ed_t3,
        ed_t4, ed_t5, ed_t6, ed_t8, ed_first_clvg_time, ed_compact_start, ed_compacted_time, ed_cavitation_start,
        ed_full_blast, ed_expand_time, ed_hatching_start, et_etdt, et_cat, et_frzdt, et_dscrdt, et_etwith,
        et_hcgtest, et_cp, et_gstsacs, et_prresult, et_brthdate, et_nbqtty, et_nbweight, vcs_srvrserial,
        vcs_scale
    FROM source.embryo_data
    WHERE NOT EXISTS (
        SELECT 1 FROM embryo_data WHERE embryo_data.ed_uuid = source.embryo_data.ed_uuid
    );

    -- Вставка данных в well_timeline
    INSERT OR IGNORE INTO well_timeline (
        wtl_id, wtl_ed_uuid, wtl_focus, wtl_tempr, wtl_gas_co2, wtl_co2_concentration, wtl_co2_flow, wtl_frame_dt
    )
    SELECT
        wtl_id, wtl_ed_uuid, wtl_focus, wtl_tempr, wtl_gas_co2, wtl_co2_concentration, wtl_co2_flow, wtl_frame_dt
    FROM source.well_timeline
    WHERE NOT EXISTS (
        SELECT 1 FROM well_timeline WHERE well_timeline.wtl_id = source.well_timeline.wtl_id AND well_timeline.wtl_ed_uuid = source.well_timeline.wtl_ed_uuid
    );

    -- Вставка данных в well_timeline_frames
    INSERT OR IGNORE INTO well_timeline_frames (
        wtf_wtl_id, wtf_ed_uuid, wtf_rel_focus, wtf_frame, wtf_dif, wtf_stabilized
    )
    SELECT
        wtf_wtl_id, wtf_ed_uuid, wtf_rel_focus, wtf_frame, wtf_dif, wtf_stabilized
    FROM source.well_timeline_frames
    WHERE NOT EXISTS (
        SELECT 1 FROM well_timeline_frames
        WHERE well_timeline_frames.wtf_wtl_id = source.well_timeline_frames.wtf_wtl_id
          AND well_timeline_frames.wtf_ed_uuid = source.well_timeline_frames.wtf_ed_uuid
          AND well_timeline_frames.wtf_rel_focus = source.well_timeline_frames.wtf_rel_focus
    );

    -- Вставка данных в embryo_focus
    INSERT OR IGNORE INTO embryo_focus (
        ef_ed_uuid, ef_focus, ef_wtl_id
    )
    SELECT
        ef_ed_uuid, ef_focus, ef_wtl_id
    FROM source.embryo_focus
    WHERE NOT EXISTS (
        SELECT 1 FROM embryo_focus
        WHERE embryo_focus.ef_ed_uuid = source.embryo_focus.ef_ed_uuid
          AND embryo_focus.ef_wtl_id = source.embryo_focus.ef_wtl_id
    );

    DETACH DATABASE source;
EOF

    # Проверка на наличие ошибки
    if [ $? -ne 0 ]; then
        echo "Ошибка при обработке файла $ev2_file"
        exit 1
    fi

    echo "Файл $ev2_file обработан."
done

echo "Все файлы .ev2 обработаны и объединены в $MAIN_DB."
