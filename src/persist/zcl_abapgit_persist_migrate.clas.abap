CLASS zcl_abapgit_persist_migrate DEFINITION PUBLIC CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS: run RAISING zcx_abapgit_exception.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_settings_to_migrate,
             name  TYPE string,
             value TYPE string,
           END OF ty_settings_to_migrate,
           tty_settings_to_migrate TYPE STANDARD TABLE OF ty_settings_to_migrate
                                        WITH NON-UNIQUE DEFAULT KEY.

    CONSTANTS c_text TYPE string VALUE 'Generated by abapGit' ##NO_TEXT.

    CLASS-METHODS table_create
      RAISING
        zcx_abapgit_exception .
    CLASS-METHODS table_exists
      RETURNING
        VALUE(rv_exists) TYPE abap_bool .
    CLASS-METHODS lock_create
      RAISING
        zcx_abapgit_exception .
    CLASS-METHODS lock_exists
      RETURNING
        VALUE(rv_exists) TYPE abap_bool .
    CLASS-METHODS migrate_settings
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS migrate_setting
      IMPORTING
        iv_name                TYPE string
      CHANGING
        ct_settings_to_migrate TYPE tty_settings_to_migrate
        ci_document            TYPE REF TO if_ixml_document.
    CLASS-METHODS distribute_settings_to_users
      IMPORTING
        it_settings_to_migrate TYPE tty_settings_to_migrate
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS update_global_settings
      IMPORTING
        ii_document TYPE REF TO if_ixml_document
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS read_global_settings_xml
      RETURNING
        VALUE(rv_global_settings_xml) TYPE string
      RAISING
        zcx_abapgit_not_found.
    CLASS-METHODS get_global_settings_document
      RETURNING
        VALUE(ri_global_settings_dom) TYPE REF TO if_ixml_document
      RAISING
        zcx_abapgit_not_found.

ENDCLASS.



CLASS ZCL_ABAPGIT_PERSIST_MIGRATE IMPLEMENTATION.


  METHOD distribute_settings_to_users.

    TYPES: ty_char12 TYPE c LENGTH 12.

    DATA: lt_abapgit_users    TYPE STANDARD TABLE OF ty_char12
                                   WITH NON-UNIQUE DEFAULT KEY,
          ls_user_settings    TYPE zif_abapgit_definitions=>ty_s_user_settings,
          li_user_persistence TYPE REF TO zif_abapgit_persist_user.

    FIELD-SYMBOLS: <lv_user>                      LIKE LINE OF lt_abapgit_users,
                   <ls_setting_to_migrate>        TYPE ty_settings_to_migrate,
                   <lg_user_specific_setting_val> TYPE data.

    " distribute settings to all abapGit users
    SELECT value FROM (zcl_abapgit_persistence_db=>c_tabname)
                 INTO TABLE lt_abapgit_users
                 WHERE type = zcl_abapgit_persistence_db=>c_type_user.

    LOOP AT lt_abapgit_users ASSIGNING <lv_user>.

      li_user_persistence = zcl_abapgit_persistence_user=>get_instance( <lv_user> ).

      ls_user_settings = li_user_persistence->get_settings( ).

      LOOP AT it_settings_to_migrate ASSIGNING <ls_setting_to_migrate>.

        ASSIGN COMPONENT <ls_setting_to_migrate>-name
               OF STRUCTURE ls_user_settings
               TO <lg_user_specific_setting_val>.
        ASSERT sy-subrc = 0.

        <lg_user_specific_setting_val> = <ls_setting_to_migrate>-value.

      ENDLOOP.

      li_user_persistence->set_settings( ls_user_settings ).

    ENDLOOP.

  ENDMETHOD.


  METHOD get_global_settings_document.

    DATA: lv_global_settings_xml TYPE string.

    lv_global_settings_xml = read_global_settings_xml( ).

    ri_global_settings_dom = cl_ixml_80_20=>parse_to_document( stream_string = lv_global_settings_xml ).

  ENDMETHOD.


  METHOD lock_create.

    DATA: lv_obj_name TYPE tadir-obj_name,
          ls_dd25v    TYPE dd25v,
          lt_dd26e    TYPE STANDARD TABLE OF dd26e WITH DEFAULT KEY,
          lt_dd27p    TYPE STANDARD TABLE OF dd27p WITH DEFAULT KEY.

    FIELD-SYMBOLS: <ls_dd26e> LIKE LINE OF lt_dd26e,
                   <ls_dd27p> LIKE LINE OF lt_dd27p.


    ls_dd25v-viewname   = zcl_abapgit_persistence_db=>c_lock.
    ls_dd25v-aggtype    = 'E'.
    ls_dd25v-roottab    = zcl_abapgit_persistence_db=>c_tabname.
    ls_dd25v-ddlanguage = zif_abapgit_definitions=>c_english.
    ls_dd25v-ddtext     = c_text.

    APPEND INITIAL LINE TO lt_dd26e ASSIGNING <ls_dd26e>.
    <ls_dd26e>-viewname   = zcl_abapgit_persistence_db=>c_lock.
    <ls_dd26e>-tabname    = zcl_abapgit_persistence_db=>c_tabname.
    <ls_dd26e>-tabpos     = '0001'.
    <ls_dd26e>-fortabname = zcl_abapgit_persistence_db=>c_tabname.
    <ls_dd26e>-enqmode    = 'E'.

    APPEND INITIAL LINE TO lt_dd27p ASSIGNING <ls_dd27p>.
    <ls_dd27p>-viewname  = zcl_abapgit_persistence_db=>c_lock.
    <ls_dd27p>-objpos    = '0001'.
    <ls_dd27p>-viewfield = 'TYPE'.
    <ls_dd27p>-tabname   = zcl_abapgit_persistence_db=>c_tabname.
    <ls_dd27p>-fieldname = 'TYPE'.
    <ls_dd27p>-keyflag   = abap_true.

    APPEND INITIAL LINE TO lt_dd27p ASSIGNING <ls_dd27p>.
    <ls_dd27p>-viewname  = zcl_abapgit_persistence_db=>c_lock.
    <ls_dd27p>-objpos    = '0002'.
    <ls_dd27p>-viewfield = 'VALUE'.
    <ls_dd27p>-tabname   = zcl_abapgit_persistence_db=>c_tabname.
    <ls_dd27p>-fieldname = 'VALUE'.
    <ls_dd27p>-keyflag   = abap_true.

    CALL FUNCTION 'DDIF_ENQU_PUT'
      EXPORTING
        name              = zcl_abapgit_persistence_db=>c_lock
        dd25v_wa          = ls_dd25v
      TABLES
        dd26e_tab         = lt_dd26e
        dd27p_tab         = lt_dd27p
      EXCEPTIONS
        enqu_not_found    = 1
        name_inconsistent = 2
        enqu_inconsistent = 3
        put_failure       = 4
        put_refused       = 5
        OTHERS            = 6.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'migrate, error from DDIF_ENQU_PUT' ).
    ENDIF.

    lv_obj_name = zcl_abapgit_persistence_db=>c_lock.
    CALL FUNCTION 'TR_TADIR_INTERFACE'
      EXPORTING
        wi_tadir_pgmid    = 'R3TR'
        wi_tadir_object   = 'ENQU'
        wi_tadir_obj_name = lv_obj_name
        wi_set_genflag    = abap_true
        wi_test_modus     = abap_false
        wi_tadir_devclass = '$TMP'
      EXCEPTIONS
        OTHERS            = 1.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'migrate, error from TR_TADIR_INTERFACE' ).
    ENDIF.

    CALL FUNCTION 'DDIF_ENQU_ACTIVATE'
      EXPORTING
        name        = zcl_abapgit_persistence_db=>c_lock
      EXCEPTIONS
        not_found   = 1
        put_failure = 2
        OTHERS      = 3.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'migrate, error from DDIF_ENQU_ACTIVATE' ).
    ENDIF.

  ENDMETHOD.


  METHOD lock_exists.

    DATA: lv_viewname TYPE dd25l-viewname.


    SELECT SINGLE viewname FROM dd25l INTO lv_viewname
      WHERE viewname = zcl_abapgit_persistence_db=>c_lock.
    rv_exists = boolc( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD migrate_setting.

    DATA: li_element            TYPE REF TO if_ixml_element,
          ls_setting_to_migrate LIKE LINE OF ct_settings_to_migrate.

    li_element = ci_document->find_from_name( iv_name ).
    IF li_element IS BOUND.

      " The element is present in the global config.
      " Therefore we have to migrate it

      ls_setting_to_migrate-name = iv_name.
      ls_setting_to_migrate-value = li_element->get_value( ).
      INSERT ls_setting_to_migrate INTO TABLE ct_settings_to_migrate.

      li_element->remove_node( ).

    ENDIF.

  ENDMETHOD.


  METHOD migrate_settings.

    DATA: li_global_settings_document TYPE REF TO if_ixml_document,
          lt_settings_to_migrate      TYPE tty_settings_to_migrate,
          lx_error                    TYPE REF TO zcx_abapgit_not_found.

    " migrate global settings to user specific settings

    TRY.
        li_global_settings_document = get_global_settings_document( ).

      CATCH zcx_abapgit_not_found INTO lx_error.
        " No global settings available, nothing todo.
        RETURN.
    ENDTRY.

    migrate_setting(
      EXPORTING
        iv_name                = |MAX_LINES|
      CHANGING
        ct_settings_to_migrate = lt_settings_to_migrate
        ci_document            = li_global_settings_document ).

    migrate_setting(
      EXPORTING
        iv_name                = |ADT_JUMP_ENABLED|
      CHANGING
        ct_settings_to_migrate = lt_settings_to_migrate
        ci_document            = li_global_settings_document ).

    IF lines( lt_settings_to_migrate ) > 0.

      distribute_settings_to_users( lt_settings_to_migrate ).

      update_global_settings( li_global_settings_document ).

    ENDIF.

  ENDMETHOD.


  METHOD read_global_settings_xml.

    rv_global_settings_xml = zcl_abapgit_persistence_db=>get_instance( )->read(
        iv_type  = zcl_abapgit_persistence_db=>c_type_settings
        iv_value = '' ).

  ENDMETHOD.


  METHOD run.

    IF table_exists( ) = abap_false.
      table_create( ).
    ENDIF.

    IF lock_exists( ) = abap_false.
      lock_create( ).
    ENDIF.

    migrate_settings( ).

  ENDMETHOD.


  METHOD table_create.

    DATA: lv_rc       LIKE sy-subrc,
          lv_obj_name TYPE tadir-obj_name,
          ls_dd02v    TYPE dd02v,
          ls_dd09l    TYPE dd09l,
          lt_dd03p    TYPE STANDARD TABLE OF dd03p WITH DEFAULT KEY.

    FIELD-SYMBOLS: <ls_dd03p> LIKE LINE OF lt_dd03p.

    ls_dd02v-tabname    = zcl_abapgit_persistence_db=>c_tabname.
    ls_dd02v-ddlanguage = zif_abapgit_definitions=>c_english.
    ls_dd02v-tabclass   = 'TRANSP'.
    ls_dd02v-ddtext     = c_text.
    ls_dd02v-contflag   = 'L'.
    ls_dd02v-exclass    = '1'.

    ls_dd09l-tabname  = zcl_abapgit_persistence_db=>c_tabname.
    ls_dd09l-as4local = 'A'.
    ls_dd09l-tabkat   = '1'.
    ls_dd09l-tabart   = 'APPL1'.
    ls_dd09l-bufallow = 'N'.

    APPEND INITIAL LINE TO lt_dd03p ASSIGNING <ls_dd03p>.
    <ls_dd03p>-tabname   = zcl_abapgit_persistence_db=>c_tabname.
    <ls_dd03p>-fieldname = 'TYPE'.
    <ls_dd03p>-position  = '0001'.
    <ls_dd03p>-keyflag   = 'X'.
    <ls_dd03p>-datatype  = 'CHAR'.
    <ls_dd03p>-leng      = '000012'.

    APPEND INITIAL LINE TO lt_dd03p ASSIGNING <ls_dd03p>.
    <ls_dd03p>-tabname   = zcl_abapgit_persistence_db=>c_tabname.
    <ls_dd03p>-fieldname = 'VALUE'.
    <ls_dd03p>-position  = '0002'.
    <ls_dd03p>-keyflag   = 'X'.
    <ls_dd03p>-datatype  = 'CHAR'.
    <ls_dd03p>-leng      = '000012'.

    APPEND INITIAL LINE TO lt_dd03p ASSIGNING <ls_dd03p>.
    <ls_dd03p>-tabname   = zcl_abapgit_persistence_db=>c_tabname.
    <ls_dd03p>-fieldname = 'DATA_STR'.
    <ls_dd03p>-position  = '0003'.
    <ls_dd03p>-datatype  = 'STRG'.

    CALL FUNCTION 'DDIF_TABL_PUT'
      EXPORTING
        name              = zcl_abapgit_persistence_db=>c_tabname
        dd02v_wa          = ls_dd02v
        dd09l_wa          = ls_dd09l
      TABLES
        dd03p_tab         = lt_dd03p
      EXCEPTIONS
        tabl_not_found    = 1
        name_inconsistent = 2
        tabl_inconsistent = 3
        put_failure       = 4
        put_refused       = 5
        OTHERS            = 6.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'migrate, error from DDIF_TABL_PUT' ).
    ENDIF.

    lv_obj_name = zcl_abapgit_persistence_db=>c_tabname.
    CALL FUNCTION 'TR_TADIR_INTERFACE'
      EXPORTING
        wi_tadir_pgmid    = 'R3TR'
        wi_tadir_object   = 'TABL'
        wi_tadir_obj_name = lv_obj_name
        wi_set_genflag    = abap_true
        wi_test_modus     = abap_false
        wi_tadir_devclass = '$TMP'
      EXCEPTIONS
        OTHERS            = 1.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( 'migrate, error from TR_TADIR_INTERFACE' ).
    ENDIF.

    CALL FUNCTION 'DDIF_TABL_ACTIVATE'
      EXPORTING
        name        = zcl_abapgit_persistence_db=>c_tabname
        auth_chk    = abap_false
      IMPORTING
        rc          = lv_rc
      EXCEPTIONS
        not_found   = 1
        put_failure = 2
        OTHERS      = 3.
    IF sy-subrc <> 0 OR lv_rc <> 0.
      zcx_abapgit_exception=>raise( 'migrate, error from DDIF_TABL_ACTIVATE' ).
    ENDIF.

  ENDMETHOD.


  METHOD table_exists.

    DATA: lv_tabname TYPE dd02l-tabname.

    SELECT SINGLE tabname FROM dd02l INTO lv_tabname
      WHERE tabname = zcl_abapgit_persistence_db=>c_tabname.
    rv_exists = boolc( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD update_global_settings.

    DATA: li_ixml          TYPE REF TO if_ixml,
          lv_settings_xml  TYPE string,
          li_ostream       TYPE REF TO if_ixml_ostream,
          li_renderer      TYPE REF TO if_ixml_renderer,
          li_streamfactory TYPE REF TO if_ixml_stream_factory.

    " finally update global settings
    " migrated elements are already removed from document

    li_ixml = cl_ixml=>create( ).
    li_streamfactory = li_ixml->create_stream_factory( ).
    li_ostream = li_streamfactory->create_ostream_cstring( lv_settings_xml ).
    li_renderer = li_ixml->create_renderer( ostream  = li_ostream
                                            document = ii_document ).
    li_renderer->render( ).

    zcl_abapgit_persistence_db=>get_instance( )->update(
      iv_type  = zcl_abapgit_persistence_db=>c_type_settings
      iv_value = ''
      iv_data  = lv_settings_xml ).

  ENDMETHOD.
ENDCLASS.
