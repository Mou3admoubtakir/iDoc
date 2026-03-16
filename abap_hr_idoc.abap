*&---------------------------------------------------------------------*
*& Report ZHRUO_CREATE_IDOC_V3
*&---------------------------------------------------------------------*
*& Programme complet de gestion d'IDocs HRMD_A pour les unités organisationnelles
*& - Création, Modification, Délimitation des objets O, S, C
*& - Gestion multiple des relations (A002, A003, B002, B003, A012)
*& - VERSION CORRIGÉE: Utilisation de MASTER_IDOC_DISTRIBUTE
*&---------------------------------------------------------------------*
REPORT zhr_f040_v0.
*---------------------------------------------------------------------*
* TYPES
*---------------------------------------------------------------------*
INCLUDE ZHR_F040_TOP.
INCLUDE ZHR_F040_SEL.
INCLUDE ZHR_F040_FORM.

START-OF-SELECTION.

* Lire et traiter  le fichier des UOs
  PERFORM read_file USING 'O'.
  PERFORM parse_file.
  PERFORM sort_table.
  PERFORM generate_idocs_om USING 'O' 'A' '002' 'O'.
* Lire et traiter le fichier des affectations
  PERFORM read_file USING 'S'.
  PERFORM parse_file.
  PERFORM generate_idocs_om USING 'S' 'A' '003' 'O'.
* Lire et traiter le fichier Managé/Manager
* Affichage des statistiques de chargement
  PERFORM f_afficher_stats.
  
*&---------------------------------------------------------------------*
*& Include          ZHRUO_CREATE_IDOC_TOP
*&---------------------------------------------------------------------*
*----------------------------------------------------------------------*
* TYPES
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_fichier,
         ligne TYPE string,
       END OF ty_fichier.

*----------------------------------------------------------------------*
* DONNÉES
*----------------------------------------------------------------------*
DATA: gt_us      TYPE TABLE OF ty_fichier,  " Unités structurelles
      gt_affect  TYPE TABLE OF ty_fichier,  " Affectations salariés
      gt_manager TYPE TABLE OF ty_fichier.  " Manager/Managé

DATA: gv_fichier_us      TYPE string,
      gv_fichier_affect  TYPE string,
      gv_fichier_manager TYPE string,
      lv_rc    TYPE i,
      gv_objid TYPE hrobjid.

TYPES: BEGIN OF ty_uo,
         code_ou        TYPE SHORT_D, "string,
         libelle_ou     TYPE hrp1000-stext,
         statut         TYPE char3,
         date_effet     TYPE BEGDATUM,
         code_ou_parent TYPE SOBID, "string,
         otype          TYPE otype,
         objid          TYPE hrobjid,
       END OF ty_uo,

      BEGIN OF ty_uo_res,
         LIGHT          TYPE CHAR4,
         code_ou        TYPE SHORT_D, "string,
         libelle_ou     TYPE hrp1000-stext,
         statut         TYPE char3,
         date_effet     TYPE BEGDATUM,
         code_ou_parent TYPE SOBID, "string,
         otype          TYPE otype,
         objid          TYPE hrobjid,
         comment        TYPE char100,
       END OF ty_uo_res.
DATA: gt_uo           TYPE STANDARD TABLE OF ty_uo,
      gt_uo_traitees  TYPE STANDARD TABLE OF ty_uo_res,
      gs_uo           TYPE ty_uo,
      gs_uo_traitee   TYPE ty_uo_res.

FIELD-SYMBOLS:    <gt_data>  TYPE STANDARD TABLE,
                  <ls_data> TYPE any.

*&---------------------------------------------------------------------*
*& Include          ZHRUO_CREATE_IDOC_SEL
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* ÉCRAN DE SÉLECTION
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_us      TYPE localfile OBLIGATORY,  " Unités structurelles
              p_affect  TYPE localfile. "OBLIGATORY,  " Affectations salariés
*              p_manage TYPE localfile. " OBLIGATORY.  " Manager/Managé
SELECTION-SCREEN END OF BLOCK b1.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS P_test LIKE pp0c-test DEFAULT 'X'.                 "B90K003337
SELECTION-SCREEN COMMENT                                    "B90K003337
  45(30) text-002 FOR FIELD P_test.                           "B90K003337
SELECTION-SCREEN END OF LINE.

*----------------------------------------------------------------------*
* TEXTES DE L'ÉCRAN DE SÉLECTION
*----------------------------------------------------------------------*
* TEXT-001 = 'Sélection des fichiers RH'
* Label de p_us      = 'Fichier Unités Structurelles'
* Label de p_affect  = 'Fichier Affectations Salariés'
* Label de p_manager = 'Fichier Manager / Managé'

*----------------------------------------------------------------------*
* ÉVÉNEMENTS
*----------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_us.
  PERFORM f_browse_fichier CHANGING p_us.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_affect.
  PERFORM f_browse_fichier CHANGING p_affect.

*AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_manage.
*  PERFORM f_browse_fichier CHANGING p_manage.

*AT SELECTION-SCREEN.
*  PERFORM f_valider_extensions.
*&---------------------------------------------------------------------*
*& Include          ZHRUO_CREATE_IDOC_FORM
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*²
* FORMS
*----------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form F_BROWSE_FICHIER
*& Ouvre une boîte de dialogue pour sélectionner un fichier local
*&---------------------------------------------------------------------*
FORM f_browse_fichier CHANGING cv_fichier TYPE localfile.

  DATA: lv_fichier TYPE string,
        lt_uos     TYPE filetable,
        lv_rc      TYPE i,
        lv_action  TYPE i.

  lv_fichier = cv_fichier.

  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title            = 'Sélectionner un fichier'
      default_extension       = 'XSLX'
      file_filter             = 'Fichiers XLSX (*.xlsx)|*.xlsx' "Fichiers texte (*.txt)|*.txt|Tous (*.*)|*.*'
      multiselection          = abap_false
    CHANGING
      file_table              = lt_uos
      rc                      = lv_rc
      user_action             = lv_action
    EXCEPTIONS
      file_open_dialog_failed = 1
      cntl_error              = 2
      error_no_gui            = 3
      not_supported_by_gui    = 4
      OTHERS                  = 5.

  IF sy-subrc = 0 AND lv_action = cl_gui_frontend_services=>action_ok.
    READ TABLE lt_uos INDEX 1 INTO cv_fichier.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_VALIDER_EXTENSIONS
*& Vérifie que les fichiers sélectionnés sont des CSV ou TXT
*&---------------------------------------------------------------------*
FORM f_valider_extensions.

  DATA: lv_ext TYPE string.

  " Vérification du fichier Unités Structurelles
  IF p_us IS NOT INITIAL.
    FIND REGEX '\.([^.]+)$' IN p_us SUBMATCHES lv_ext.
    TRANSLATE lv_ext TO UPPER CASE.
    IF lv_ext <> 'CSV' AND lv_ext <> 'TXT'.
      MESSAGE 'Le fichier Unités Structurelles doit être un CSV ou TXT.' TYPE 'E'.
    ENDIF.
  ENDIF.

  " Vérification du fichier Affectations
  IF p_affect IS NOT INITIAL.
    FIND REGEX '\.([^.]+)$' IN p_affect SUBMATCHES lv_ext.
    TRANSLATE lv_ext TO UPPER CASE.
    IF lv_ext <> 'CSV' AND lv_ext <> 'TXT'.
      MESSAGE 'Le fichier Affectations Salariés doit être un CSV ou TXT.' TYPE 'E'.
    ENDIF.
  ENDIF.

  " Vérification du fichier Manager/Managé
*  IF p_manage IS NOT INITIAL.
*    FIND REGEX '\.([^.]+)$' IN p_manage SUBMATCHES lv_ext.
*    TRANSLATE lv_ext TO UPPER CASE.
*    IF lv_ext <> 'CSV' AND lv_ext <> 'TXT'.
*      MESSAGE 'Le fichier Manager/Managé doit être un CSV ou TXT.' TYPE 'E'.
*    ENDIF.
*  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_CHARGER_FICHIER
*& Charge un fichier local dans une table interne
*&---------------------------------------------------------------------*
FORM f_charger_fichier USING    iv_fichier TYPE localfile
                       CHANGING ct_data    TYPE STANDARD TABLE.

  DATA: lt_raw TYPE truxs_t_text_data.

  CALL FUNCTION 'TEXT_CONVERT_XLS_TO_SAP'
    EXPORTING
      i_line_header        = abap_true
      i_tab_raw_data       = lt_raw
      i_filename           = iv_fichier
    TABLES
      i_tab_converted_data = ct_data
    EXCEPTIONS
      conversion_failed    = 1
      OTHERS               = 2.

  IF sy-subrc <> 0.
    " Fallback : chargement brut ligne par ligne (CSV/TXT)
    CLEAR ct_data.
    CALL FUNCTION 'GUI_UPLOAD'
      EXPORTING
        filename                = iv_fichier
        filetype                = 'ASC'
        has_field_separator     = abap_true
      TABLES
        data_tab                = ct_data
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        unknown_error           = 7
        bad_data_format         = 8
        header_not_allowed      = 9
        separator_not_allowed   = 10
        header_too_long         = 11
        unknown_dp_error        = 12
        access_denied           = 13
        dp_out_of_memory        = 14
        disk_full               = 15
        dp_timeout              = 16
        OTHERS                  = 17.

    IF sy-subrc <> 0.
      MESSAGE |Erreur lors du chargement du fichier : { iv_fichier }| TYPE 'W'.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_AFFICHER_STATS
*& Affiche un récapitulatif du chargement
*&---------------------------------------------------------------------*
FORM f_afficher_stats.

*  WRITE: / '================================================'.
*  WRITE: / ' Récapitulatif du chargement des fichiers HR4YOU'.
*  WRITE: / '================================================'.
*  WRITE: / ' Unités structurelles  :',
*           LINES( gt_uo ),      'ligne(s) chargée(s)'.
*  WRITE: / ' Affectations salariés :',
*           LINES( gt_affect ),  'ligne(s) chargée(s)'.
*  WRITE: / ' Manager / Managé      :',
*           LINES( gt_manager ), 'ligne(s) chargée(s)'.
*  WRITE: / '================================================'.

  LOOP AT gt_uo_traitees INTO gs_uo_traitee.

    CASE gs_uo_traitee-light.
      WHEN 'G'.
        WRITE icon_green_light AS ICON TO gs_uo_traitee-light.
      WHEN 'R'.
        WRITE icon_red_light AS ICON TO gs_uo_traitee-light.
    ENDCASE.

    MODIFY gt_uo_traitees FROM gs_uo_traitee.

  ENDLOOP.

  DATA: lo_alv TYPE REF TO cl_salv_table,
        lv_exc TYPE REF TO cx_salv_msg.
  CREATE OBJECT lv_exc.
  TRY.
      CALL METHOD cl_salv_table=>factory
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = gt_uo_traitees. " Table à afficher
      " Afficher l'ALV
      lo_alv->display( ).
    CATCH cx_salv_msg INTO lv_exc.
      WRITE: / 'Erreur ALV :  '.", LV_EXC->GET_TEXT( ).
  ENDTRY.

ENDFORM.
*---------------------------------------------------------------------*
* READ FILE
*---------------------------------------------------------------------*
FORM read_file USING p_file TYPE otype.

  DATA : lv_filename      TYPE string,

         lt_records       TYPE solix_tab,
         lv_headerxstring TYPE xstring,
         lv_filelength    TYPE i.

  IF <gt_data> IS ASSIGNED.
    CLEAR <gt_data>.
  ENDIF.

  CASE p_file.
    WHEN 'O'.
      lv_filename = p_us.
    WHEN 'S'.
      lv_filename = p_affect.
*    WHEN 'P'.
*      lv_filename = p_manage.
  ENDCASE.
  CALL FUNCTION 'GUI_UPLOAD'
    EXPORTING
      filename                = lv_filename
      filetype                = 'BIN'
    IMPORTING
      filelength              = lv_filelength
      header                  = lv_headerxstring
    TABLES
      data_tab                = lt_records
    EXCEPTIONS
      file_open_error         = 1
      file_read_error         = 2
      no_batch                = 3
      gui_refuse_filetransfer = 4
      invalid_type            = 5
      no_authority            = 6
      unknown_error           = 7
      bad_data_format         = 8
      header_not_allowed      = 9
      separator_not_allowed   = 10
      header_too_long         = 11
      unknown_dp_error        = 12
      access_denied           = 13
      dp_out_of_memory        = 14
      disk_full               = 15
      dp_timeout              = 16
      OTHERS                  = 17.

  "convert binary data to xstring
  "if you are using cl_fdt_xl_spreadsheet in odata then skips this step
  "as excel file will already be in xstring
  CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
    EXPORTING
      input_length = lv_filelength
    IMPORTING
      buffer       = lv_headerxstring
    TABLES
      binary_tab   = lt_records
    EXCEPTIONS
      failed       = 1
      OTHERS       = 2.

  IF sy-subrc <> 0.
    "Implement suitable error handling here
  ENDIF.

  DATA : lo_excel_ref TYPE REF TO cl_fdt_xl_spreadsheet .

  TRY .
      lo_excel_ref = NEW cl_fdt_xl_spreadsheet(
                              document_name = lv_filename
                              xdocument     = lv_headerxstring ) .
    CATCH cx_fdt_excel_core.
      "Implement suitable error handling here

  ENDTRY .

  "Get List of Worksheets
  lo_excel_ref->if_fdt_doc_spreadsheet~get_worksheet_names(
    IMPORTING
      worksheet_names = DATA(lt_worksheets) ).

  IF NOT lt_worksheets IS INITIAL.
    READ TABLE lt_worksheets INTO DATA(lv_woksheetname) INDEX 1.

    DATA(lo_data_ref) = lo_excel_ref->if_fdt_doc_spreadsheet~get_itab_from_worksheet(
                                             lv_woksheetname ).
    "now you have excel work sheet data in dyanmic internal table
    ASSIGN lo_data_ref->* TO <gt_data>.
  ENDIF.


ENDFORM.
*---------------------------------------------------------------------*
* GENERATE PARSE_FILE
*---------------------------------------------------------------------*
FORM parse_file.

  FIELD-SYMBOLS <lv_field> TYPE any.

  DATA: lo_table_descr  TYPE REF TO cl_abap_tabledescr,
        lo_struct_descr TYPE REF TO cl_abap_structdescr.

*  FIELD-SYMBOLS : <ls_data>  TYPE any.",
*                  <lv_field> TYPE any.
  CLEAR: gt_uo, gs_uo.

  TRY.
*     Use RTTI services to describe table variable
      lo_table_descr ?= cl_abap_tabledescr=>describe_by_data( p_data = <gt_data> ).
*     Use RTTI services to describe table structure
      lo_struct_descr ?= lo_table_descr->get_table_line_type( ).

*     Count number of columns in structure
      DATA(lv_number_of_columns) = lines( lo_struct_descr->components ).
    CATCH cx_sy_move_cast_error.
      "Implement error handling
  ENDTRY.

  LOOP AT <gt_data> ASSIGNING <ls_data> FROM 2 .

    "processing columns
    DO lv_number_of_columns TIMES.
      ASSIGN COMPONENT sy-index OF STRUCTURE <ls_data> TO <lv_field> .
      IF sy-subrc = 0.
        CASE sy-index.
          WHEN 1.
            gs_uo-code_ou = <lv_field>.
          WHEN 2.
            gs_uo-libelle_ou = <lv_field>.
          WHEN 3.
            gs_uo-statut = <lv_field>.
          WHEN 4.
            CONCATENATE <lv_field>(4) <lv_field>+5(2) <lv_field>+8(2) INTO gs_uo-date_effet.
          WHEN 5.
            gs_uo-code_ou_parent = <lv_field>.
        ENDCASE.
      ENDIF.
    ENDDO.
    APPEND gs_uo TO gt_uo.
  ENDLOOP.
*    gt_uo = <gt_data>.
*  SORT  gt_uo BY code_ou_parent(4) code_ou(5)." ASCENDING.
ENDFORM.

*---------------------------------------------------------------------*
* GENERATE IDOCS
*---------------------------------------------------------------------*
FORM generate_idocs_om USING p_otype   TYPE otype p_rsign TYPE rsign
                             p_relat   TYPE relat p_sclas TYPE sclas.

  DATA : lv_numberofcolumns   TYPE i,
         lv_date_string       TYPE string,
         lv_target_date_field TYPE datum.


  DATA: ls_edidc        TYPE edidc,
        lt_edidd        TYPE STANDARD TABLE OF edidd,
        lt_comm_control TYPE STANDARD TABLE OF edidc,
        lv_objid        TYPE hrobjid,
        lv_objid_parent TYPE hrobjid,
        lv_exist        TYPE boolean,
        lv_pertinent    TYPE boolean,
        lv_begda        TYPE begdatum,
        lv_stext        TYPE stext,
        lv_stext_new    TYPE stext,
        ls_edidd        TYPE edidd.

*  BREAK-POINT.

  LOOP AT gt_uo INTO gs_uo.
    DATA: ls_e1plogi TYPE e1plogi, ls_p1000 TYPE e1p1000.

    CLEAR: lv_objid, lv_exist, lv_begda, lv_stext, ls_e1plogi, lv_pertinent, ls_p1000, gs_uo_traitee.
*--- Control record
    CLEAR ls_edidc.
    ls_edidc-mestyp  = 'HRMD_A'.
    ls_edidc-idoctp  = 'HRMD_A07'.
    ls_edidc-direct  = '1'.
    ls_edidc-rcvprn  = 'SSTRECV100'.
    ls_edidc-rcvprt  = 'LS'.
    ls_edidc-sndprn  = 'SSTCLNT100'.
    ls_edidc-sndprt  = 'LS'.

*------------------------------------------------------------*
* SEGMENT E1PLOGI (Infotype 1000 - Objet O, S, C)
*------------------------------------------------------------*

    PERFORM get_new_objid USING gs_uo-code_ou p_otype CHANGING lv_objid lv_exist lv_begda lv_stext.

*    CONCATENATE gs_uo-code_ou gs_uo-libelle_ou INTO lv_stext_new SEPARATED BY ' - '.
    IF lv_exist EQ abap_true AND lv_begda EQ gs_uo-date_effet
                AND lv_begda EQ gs_uo-date_effet AND gs_uo-libelle_ou EQ lv_stext.
      CONTINUE.
    ELSEIF lv_exist EQ abap_true.
      ls_e1plogi-opera   = 'U'.
    ELSE.
      ls_e1plogi-opera   = 'I'.
    ENDIF.

    ls_e1plogi-plvar  = '01'.
    ls_e1plogi-otype   = p_otype.
    ls_e1plogi-objid   = lv_objid.
    ls_e1plogi-proof   = 'X'.

    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1PLOGI'.
    ls_edidd-sdata = ls_e1plogi.
    APPEND ls_edidd TO lt_edidd.


    DATA ls_e1pityp LIKE e1pityp.

    ls_e1pityp-plvar = '01'.
    ls_e1pityp-otype = p_otype.
    ls_e1pityp-objid = lv_objid.
    ls_e1pityp-infty = '1000'.
*    ls_E1PITYP-subty = t_hrobjinfty-subty.
    ls_e1pityp-begda = gs_uo-date_effet.
    ls_e1pityp-endda = '99991231'.

    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1PITYP'.
    ls_edidd-sdata = ls_e1pityp.
    APPEND ls_edidd TO lt_edidd.

    ls_p1000-plvar = '01'.
    ls_p1000-otype = p_otype.
    ls_p1000-objid = lv_objid.
    ls_p1000-LANGU = sy-LANGU.
    ls_p1000-infty = '1000'.
    ls_p1000-istat = '1'.
    ls_p1000-begda = gs_uo-date_effet.
    ls_p1000-endda = '99991231'.
    ls_p1000-short = gs_uo-code_ou.
    ls_p1000-stext  = gs_uo-libelle_ou.
*    CONCATENATE gs_uo-code_ou gs_uo-libelle_ou INTO ls_p1000-stext SEPARATED BY ' - '.
*    ls_p1000-stext = gs_uo-libelle_ou.

    CLEAR ls_edidd.
    ls_edidd-segnam = 'E1P1000'.
    ls_edidd-sdata = ls_p1000.
    APPEND ls_edidd TO lt_edidd.

    gs_uo-objid = lv_objid.
    gs_uo-otype = p_otype.
    MOVE-CORRESPONDING gs_uo TO gs_uo_traitee.
*------------------------------------------------------------*
* SEGMENT RELATION (Infotype 1001)
*------------------------------------------------------------*
    IF gs_uo-code_ou_parent IS NOT INITIAL.

      DATA: ls_p1001          TYPE e1p1001,
            lv_date_obj_relie TYPE BEGDATUM.

      CLEAR: lv_exist, lv_objid_parent, ls_p1001, lv_date_obj_relie.

      PERFORM get_objid_from_code USING gs_uo-code_ou_parent p_sclas CHANGING lv_objid_parent lv_date_obj_relie.

      PERFORM check_pertinence_relation USING lv_objid lv_objid_parent p_otype p_rsign p_relat gs_uo-date_effet lv_date_obj_relie
                                        CHANGING lv_pertinent.

      IF lv_objid_parent IS NOT INITIAL AND lv_pertinent EQ abap_true.
        CLEAR ls_e1pityp.

        ls_e1pityp-plvar = '01'.
        ls_e1pityp-otype = p_otype.
        ls_e1pityp-objid = lv_objid.
        ls_e1pityp-infty = '1001'.
*    ls_E1PITYP-subty = t_hrobjinfty-subty.
        ls_e1pityp-begda = gs_uo-date_effet.
        ls_e1pityp-endda = '99991231'.

        CLEAR ls_edidd.
        ls_edidd-segnam = 'E1PITYP'.
        ls_edidd-sdata = ls_e1pityp.
        APPEND ls_edidd TO lt_edidd.

        ls_p1001-plvar = '01'.
        ls_p1001-otype = p_otype.
        ls_p1001-objid = lv_objid.
        ls_p1001-infty = '1001'.
        ls_p1001-rsign = p_rsign.
        ls_p1001-relat = p_relat.
        ls_p1001-istat = '1'.
        ls_p1001-begda = gs_uo-date_effet.
        ls_p1001-endda = '99991231'.
        ls_p1001-sclas = p_sclas.
        ls_p1001-sobid = lv_objid_parent.

        CLEAR ls_edidd.
        ls_edidd-segnam = 'E1P1001'.
        ls_edidd-sdata = ls_p1001.
        APPEND ls_edidd TO lt_edidd.
        gs_uo_traitee-light = 'G'.
      ELSEIF lv_objid_parent IS INITIAL.
        gs_uo_traitee-light = 'R'.
        gs_uo_traitee-comment = text-003.
      ENDIF.
    ELSE.
      gs_uo_traitee-light = 'G'.
    ENDIF.

    APPEND gs_uo_traitee TO gt_uo_traitees.
*------------------------------------------------------------*
* DISTRIBUTE IDOC
*------------------------------------------------------------*
    IF P_test IS INITIAL AND ( gs_uo-code_ou_parent IS INITIAL OR gs_uo_traitee-light EQ 'G'). " La création d'un objet orphelin est possible juste pour le type 'O'
      CALL FUNCTION 'MASTER_IDOC_DISTRIBUTE'
        EXPORTING
          master_idoc_control        = ls_edidc
        TABLES
          communication_idoc_control = lt_comm_control
          master_idoc_data           = lt_edidd
        EXCEPTIONS
          OTHERS                     = 1.

      IF sy-subrc = 0.
        COMMIT WORK.
      ELSE.
        ROLLBACK WORK.
      ENDIF.
    ENDIF.
    CLEAR lt_edidd.

  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_short_exist
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> gs_uo_CODE_OU
*&      <-- LV_EXIST
*&---------------------------------------------------------------------*
FORM get_objid_from_code  USING    p_code_ou TYPE sobid p_otype TYPE otype
                          CHANGING p_objid TYPE hrobjid p_dateeffe TYPE BEGDATUM.
  DATA: ll_objid TYPE hrobjid,
        ll_begda TYPE BEGDATUM,
        ls_uo    TYPE ty_uo_res.

  IF p_code_ou IS NOT INITIAL. "Les objets ne sont peut être pas encore écrites en BDD donc commencer par chercher en mémoire
    READ TABLE gt_uo_traitees INTO ls_uo WHERE code_ou = p_code_ou AND otype = p_otype.
    IF sy-subrc EQ 0 AND ls_uo-objid IS NOT INITIAL.
      p_objid  = ls_uo-objid.
      ll_begda = ls_uo-date_effet.
    ELSE.
      SELECT SINGLE objid begda INTO (ll_objid, ll_begda)
        FROM hrp1000
        WHERE short = p_code_ou AND otype = p_otype AND endda EQ '99991231'.
      IF sy-subrc EQ 0.
        p_objid     = ll_objid.
        p_dateeffe  = ll_begda.
      ENDIF.
    ENDIF.
  ENDIF.
ENDFORM.

FORM get_new_objid       USING    p_code_ou TYPE short_d p_otype TYPE otype
                         CHANGING p_objid TYPE hrobjid p_exist TYPE boolean p_begda TYPE d p_stext TYPE stext.
  DATA: ll_objid TYPE hrobjid,
        ls_uo    TYPE ty_uo_res,
        ll_begda TYPE d,
        ll_stext TYPE stext,
        ll_exist TYPE boolean.

    CHECK p_code_ou IS NOT INITIAL.

    "--- Priorité : recherche en mémoire (objets en cours de traitement)
    READ TABLE gt_uo_traitees INTO ls_uo WHERE code_ou = p_code_ou AND otype = p_otype.

    IF sy-subrc = 0 AND ls_uo-objid IS NOT INITIAL.
      p_objid    = ls_uo-objid.
      p_begda    = ls_uo-date_effet.
      p_exist    = abap_true.
      p_stext    = ls_uo-libelle_ou.
      RETURN.
    ELSE.
      "--- PRecherche en BDD, si le code existe déjà en BDD, alors retourner la date d'effet et le stext
      SELECT SINGLE objid begda stext INTO (ll_objid, ll_begda, ll_stext)
        FROM hrp1000
        WHERE otype = p_otype
          AND short = p_code_ou
          AND endda = '99991231'.

      IF sy-subrc = 0.
        p_objid = ll_objid.
        p_exist = abap_true.
        p_begda = ll_begda.
        p_stext = ll_stext.
        RETURN.
      ENDIF.
    ENDIF.

  IF gv_objid IS INITIAL.
    CALL FUNCTION 'Z_GET_NEXT_EXTERN_ID'
      EXPORTING
        otype  = p_otype
        plvar  = '01'
      IMPORTING
        number = ll_objid.

    gv_objid = ll_objid.
    p_objid = ll_objid.
  ELSE.
    p_objid  = gv_objid + 1.
    gv_objid = gv_objid + 1.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_pertinence_relation
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_OBJID
*&      --> LV_OBJID_PARENT
*&      --> gs_uo_DATE_EFFET
*&      <-- LV_PERTINENT
*&---------------------------------------------------------------------*
FORM check_pertinence_relation  USING    p_objid        TYPE hrobjid  p_objid_parent TYPE hrobjid p_otype TYPE otype
                                         p_rsign TYPE rsign p_relat TYPE relat p_date_effet   TYPE begdatum p_date_obj_rel TYPE begdatum
                                CHANGING p_pertinent    TYPE boolean.

  DATA: ll_objid_parent TYPE sobid,
        ll_begda        TYPE begdatum.

  SELECT SINGLE sobid begda INTO (ll_objid_parent, ll_begda)
    FROM hrp1001
    WHERE plvar = '01' AND otype = p_otype AND objid = p_objid AND rsign = p_relat AND relat = p_relat AND istat = '1'.

  IF sy-subrc EQ 0 AND ll_objid_parent EQ ll_objid_parent AND ll_begda EQ p_date_effet.
    p_pertinent = abap_false.
  ELSEIF p_date_effet LT p_date_obj_rel.
    p_pertinent = abap_false.
    gs_uo_traitee-light = 'R'.
    gs_uo_traitee-comment = text-004.
  ELSE.
    p_pertinent = abap_true.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*& Form SORT_TABLE
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> GT_TABLE
*&      <-- GT_TABLE
*&---------------------------------------------------------------------*
FORM sort_table.

  DATA: lt_uo      TYPE TABLE OF ty_uo,
        lt_added   TYPE TABLE OF ty_uo,
        lt_current TYPE TABLE OF ty_uo,
        lv_lines   TYPE i.

  " Étape 1 : Lignes racines (sans parent)
  lt_added = VALUE #( FOR ls_line IN gt_uo
                      WHERE ( code_ou_parent IS INITIAL )
                      ( ls_line ) ).

  DELETE gt_uo WHERE code_ou_parent IS INITIAL.

  APPEND LINES OF lt_added TO lt_uo.

  " Étapes 2 & 3 : Boucle jusqu'à épuisement de gt_uo
  WHILE gt_uo IS NOT INITIAL.

    CLEAR lt_current.

    LOOP AT gt_uo ASSIGNING FIELD-SYMBOL(<ls_line>).
      READ TABLE lt_added WITH KEY code_ou = <ls_line>-code_ou_parent
                          TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        APPEND <ls_line> TO lt_current.
      ENDIF.
    ENDLOOP.

    IF lt_current IS INITIAL.
      " Sécurité : éviter une boucle infinie si des orphelins existent
      MESSAGE 'Erreur critique : Des lignes orphelines existent dans la liste des UOs' TYPE 'E'.
      LEAVE PROGRAM.
      APPEND LINES OF gt_uo TO lt_uo.
      CLEAR gt_uo.
      EXIT.
    ENDIF.

    LOOP AT lt_current ASSIGNING FIELD-SYMBOL(<ls_current>).
      DELETE gt_uo WHERE code_ou = <ls_current>-code_ou.
    ENDLOOP.

    APPEND LINES OF lt_current TO lt_uo.

    " lt_added devient lt_current pour la prochaine itération
    lt_added = lt_current.

  ENDWHILE.

  APPEND LINES OF lt_uo TO gt_uo.

ENDFORM.				  