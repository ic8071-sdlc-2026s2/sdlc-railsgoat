# Mapa de la app · OWASP RailsGoat (MetaCorp)

Este documento es su punto de partida para la fase 1. Describe qué hace la app, quién la usa, qué datos guarda y dónde vive cada parte del código. No señala debilidades: encontrarlas es su trabajo en las fases siguientes.

Lean esto con la app levantada al lado (`bash lab/app.sh levantar`) y recórranla como usuario durante unos minutos.

## Qué es

RailsGoat simula el portal interno de recursos humanos y nómina de una empresa ficticia, **MetaCorp** («A GoatGroup Company»). Es una aplicación web monolítica: un empleado inicia sesión y consulta su información laboral, su salario, su plan de retiro, sus vacaciones y sus mensajes internos. Un administrador gestiona las cuentas de los empleados y revisa estadísticas de uso.

Está hecha con **Ruby on Rails 8.0** sobre **Ruby 3.4.1**, con base de datos **SQLite** en desarrollo. Las vistas son HTML renderizado en el servidor (plantillas ERB) con algo de JavaScript (jQuery) para los formularios por AJAX. Hay además una pequeña API JSON para clientes móviles.

> La app corre en el puerto 3000 dentro del contenedor; el laboratorio la publica en `http://localhost:3104` de su máquina. La ruta de salud es `/` (la pantalla de inicio de sesión).

## Roles

| Rol | Cómo se obtiene | Qué puede hacer |
|:---|:---|:---|
| Visitante anónimo | Sin sesión | Ver la pantalla de inicio de sesión, registrarse, pedir restablecer la contraseña |
| Empleado | Registrarse o iniciar sesión | Ver y editar su cuenta, su información laboral, su salario y depósito directo, su retiro, sus vacaciones, su desempeño y sus mensajes |
| Administrador | Una cuenta con el atributo `admin` activo | Todo lo del empleado, más gestionar las cuentas de otros empleados y ver las estadísticas de acceso |

El rol se guarda como un atributo booleano (`admin`) en la cuenta de cada usuario.

## Cuentas de prueba (las crean las seeds)

Al levantar la app con `rails db:setup`, el archivo `db/seeds.rb` crea siete cuentas. Todas usan el dominio `@metacorp.com`:

| Correo | Contraseña | Rol |
|:---|:---|:---|
| admin@metacorp.com | admin1234 | Administrador |
| admin2@metacorp.com | adminadmin | Empleado |
| jmmastey@metacorp.com | railsgoat! | Empleado |
| john@metacorp.com | yankeessuck | Empleado |
| james@metacorp.com | alohaowasp | Empleado |
| mike@metacorp.com | motocross1445 | Empleado |
| ken@metacorp.com | citrusblend | Empleado |

La cuenta de administración es la primera (id 1). La pantalla «Demo Credentials», enlazada desde el encabezado sin sesión, también muestra credenciales de ejemplo.

## Pantallas y rutas principales

| Pantalla | Ruta | Para qué sirve |
|:---|:---|:---|
| Inicio de sesión | `GET /` y `GET /login` | Entrar con correo y contraseña (pantalla MetaCorp) |
| Registro | `GET /signup`, `POST /users` | Crear una cuenta de empleado |
| Restablecer contraseña | `GET /forgot_password`, `GET,POST /password_resets` | Pedir y confirmar el restablecimiento por correo |
| Panel (dashboard) | `GET /dashboard/home` | Página de inicio tras entrar; gráficos de resumen (`change_graph`, `bar_graph`, `pie_charts`) |
| Ajustes de cuenta | `GET /users/:id/account_settings`, `PATCH /users/:id` | Cambiar correo, nombre y contraseña |
| Información laboral | `GET /users/:id/work_info` | Salario, bonos, años en la empresa, número de seguro social, fecha de nacimiento |
| Salario y depósito | `GET /users/:id/pay`, `POST .../update_dd_info`, `POST .../decrypted_bank_acct_num` | Cuenta bancaria y porcentaje de depósito directo |
| Plan de retiro (401k) | `GET /users/:id/retirement` | Aportes del empleado y de la empresa |
| Vacaciones (PTO) | `GET /users/:id/paid_time_off`, `GET,POST /schedule` | Días de vacaciones y enfermedad; calendario de eventos |
| Desempeño | `GET /users/:id/performance` | Evaluaciones y comentarios |
| Mensajes | `GET /users/:id/messages`, `GET /users/:id/messages/:id` | Mensajería interna entre empleados |
| Formularios de beneficios | `GET /users/:id/benefit_forms`, `POST /upload`, `GET /download` | Subir y descargar archivos de beneficios |
| Administración | `GET /admin/:admin_id/dashboard`, `.../get_all_users`, `.../get_user`, `PATCH .../update_user`, `POST .../delete_user`, `.../analytics` | Gestionar empleados y ver estadísticas de acceso |
| Tutoriales | `GET /tutorials/credentials`, `.../supply_chain`, `.../check_dependencies` | Material de aprendizaje de la app |
| API JSON | `GET /api/v1/users`, `GET /api/v1/mobile` | Datos para un cliente móvil, con un token de acceso |

## Qué datos guarda

La base tiene estas tablas principales (ver `db/schema.rb`):

| Tabla | Guarda |
|:---|:---|
| `users` | Correo, contraseña (hasheada), atributo `admin`, nombre, token de autenticación |
| `work_infos` | Salario, bonos, años trabajados, **número de seguro social**, fecha de nacimiento, SSN cifrado |
| `pays` | Número de cuenta bancaria (cifrado), número de ruta, porcentaje de depósito directo |
| `retirements` | Aportes del empleado y del empleador, total |
| `paid_time_offs` y `schedules` | Días de vacaciones y enfermedad, y eventos del calendario |
| `performances` | Evaluaciones, comentarios, puntaje, revisor |
| `messages` | Mensajes internos: emisor, receptor, texto, leído |
| `analytics` | Bitácora de accesos: dirección IP, referente, agente de usuario |
| `benefits`, `key_managements` | Metadatos de archivos de beneficios y material de llaves |

En resumen, la app maneja datos personales sensibles de empleados: salario, cuenta bancaria, número de seguro social y fecha de nacimiento. Esa sensibilidad es la que da peso a los casos de abuso que ustedes escriban.

## Dónde vive cada parte en `app/`

RailsGoat sigue la estructura estándar de Ruby on Rails:

```
app/
  controllers/        reciben cada petición y deciden qué responder
    application_controller.rb    filtros comunes: sesión, autenticación, bitácora
    sessions_controller.rb       inicio y cierre de sesión
    users_controller.rb          registro y edición de cuentas
    admin_controller.rb          gestión de empleados y estadísticas
    work_info_controller.rb, pay_controller.rb, retirement_controller.rb,
    paid_time_off_controller.rb, performance_controller.rb,
    messages_controller.rb, benefit_forms_controller.rb,
    password_resets_controller.rb, dashboard_controller.rb, tutorials_controller.rb
    api/v1/users_controller.rb, api/v1/mobile_controller.rb   la API JSON
  models/             las tablas como clases Ruby (user.rb, work_info.rb, pay.rb, ...)
  views/              las plantillas HTML (.html.erb), una carpeta por controlador
    layouts/          el marco común de la página (encabezado, barra lateral, pie)
  mailers/            el correo de restablecimiento de contraseña
  helpers/            funciones auxiliares de las vistas
  assets/             CSS, imágenes y JavaScript (jQuery, Bootstrap, calendario, etc.)

config/
  routes.rb           la tabla de rutas de arriba
  database.yml         configuración de la base (SQLite en desarrollo)
  initializers/        configuración que se carga al arrancar (sesión, llaves, constantes)
  environments/        ajustes por entorno (development, production, ...)

db/
  schema.rb            definición de todas las tablas
  seeds.rb             las cuentas y datos de prueba
  migrate/             el historial de cambios al esquema

lib/
  encryption.rb        rutinas de cifrado que usa la app
```

## Por dónde empezar la fase 1

1. Entren con una cuenta de empleado (por ejemplo `john@metacorp.com`) y recorran cada pantalla de la barra lateral.
2. Entren con la cuenta de administración (`admin@metacorp.com`) y vean qué cambia.
3. Fíjense en las rutas que llevan un `:id` o un `:user_id`: ¿qué pasaría si lo cambian por el de otra persona?
4. Anoten qué datos muestra cada pantalla y cuáles son sensibles.
5. Lleven esas observaciones a OWASP Cornucopia y conviertan cada idea en un caso de abuso.
