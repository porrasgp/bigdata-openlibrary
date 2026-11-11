# Diagrama ER: modelo normalizado (esquema `openlibrary`)

GitHub renderiza este diagrama directamente. Las relaciones N:M pasan por tablas intermedias.

```mermaid
erDiagram
    OBRA ||--o{ EDICION : "tiene"
    OBRA ||--o{ OBRA_AUTOR : "escrita por"
    AUTOR ||--o{ OBRA_AUTOR : "escribe"
    EDICION ||--o{ EDICION_AUTOR : "tiene autor"
    AUTOR ||--o{ EDICION_AUTOR : "aparece en"
    EDICION ||--o{ EDICION_EDITORIAL : "publicada por"
    EDITORIAL ||--o{ EDICION_EDITORIAL : "publica"
    EDICION ||--o{ EDICION_IDIOMA : "en idioma"
    IDIOMA ||--o{ EDICION_IDIOMA : "usado en"
    OBRA ||--o{ OBRA_TEMA : "tiene tema"
    TEMA ||--o{ OBRA_TEMA : "aplica a"
    OBRA ||--o{ VALORACION : "recibe"
    EDICION o|--o{ VALORACION : "opcional"
    OBRA ||--o{ LECTURA : "leída"
    EDICION o|--o{ LECTURA : "opcional"

    OBRA {
        text clave_obra PK
        text titulo
        int anio_primera_publicacion
        int num_portadas
    }
    EDICION {
        text clave_edicion PK
        text clave_obra FK
        text titulo
        int anio_publicacion
        int decada
        int paginas
        text isbn_13
    }
    AUTOR {
        text clave_autor PK
        text nombre
        text fecha_nacimiento
    }
    OBRA_AUTOR {
        text clave_obra PK, FK
        text clave_autor PK, FK
    }
    EDICION_AUTOR {
        text clave_edicion PK, FK
        text clave_autor PK, FK
    }
    EDITORIAL {
        int editorial_id PK
        text nombre UK
    }
    EDICION_EDITORIAL {
        text clave_edicion PK, FK
        int editorial_id PK, FK
    }
    IDIOMA {
        text codigo PK
    }
    EDICION_IDIOMA {
        text clave_edicion PK, FK
        text codigo PK, FK
    }
    TEMA {
        int tema_id PK
        text nombre UK
    }
    OBRA_TEMA {
        text clave_obra PK, FK
        int tema_id PK, FK
    }
    VALORACION {
        text clave_obra FK
        text clave_edicion FK
        smallint valor
        date fecha
    }
    LECTURA {
        text clave_obra FK
        text clave_edicion FK
        text estado
        date fecha
    }
```

## Notas de diseño

- **Claves naturales**: `clave_obra`, `clave_edicion` y `clave_autor` son las claves de Open Library. Se conservan para poder volver al dato original.
- **Claves sustitutas**: `editorial_id` y `tema_id` son enteros porque los nombres pueden ser largos y tener variantes.
- **Sin clave primaria en `VALORACION` y `LECTURA`**: el dump no identifica al usuario, así que dos filas iguales pueden ser eventos distintos.
- **Relaciones opcionales** (`o|--o{`): una valoración o lectura puede no tener edición.
- **Una edición, una obra**: en el dump una edición puede apuntar a varias obras; el modelo guarda la primera. Ver `03_limpieza_spark/02_clean_a_curated.py`.
- **Esquema estrella**: ver `ddl_estrella.sql`. Las mismas valoraciones y lecturas, con dimensiones de obra y de fecha.
