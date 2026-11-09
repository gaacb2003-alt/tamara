-- =====================================================================
-- Constanza · datos iniciales (todo FICTICIO, solo para la demostración)
-- =====================================================================

-- Pantallas y acciones que el administrador puede activar
insert into public.modulos (clave, nombre, tipo, orden) values
 ('causas',             'Causas del tribunal',              'pantalla', 1),
 ('inicio',             'Inicio',                           'pantalla', 2),
 ('estado',             'Estado de la causa',               'pantalla', 3),
 ('resumen',            'Resumen con folios',               'pantalla', 4),
 ('lapsos',             'Control de lapsos',                'pantalla', 5),
 ('orientacion',        'Orientación',                      'pantalla', 6),
 ('tiempo',             'Prueba de tiempo',                 'pantalla', 7),
 ('seguridad',          'Laboratorio de seguridad',         'pantalla', 8),
 ('bitacora',           'Bitácora',                         'pantalla', 9),
 ('validar_resumen',    'Validar y corregir resúmenes',     'accion',  10),
 ('editar_calendario',  'Editar el calendario de despacho', 'accion',  11),
 ('ver_identificacion', 'Ver la identificación de las partes','accion', 12);

-- Plantilla de cada perfil (mismos accesos del prototipo original)
insert into public.rol_permisos (rol, modulo)
select r.rol, m.modulo from (values
 ('juez',        array['causas','inicio','estado','resumen','lapsos','orientacion','tiempo','seguridad','bitacora','ver_identificacion']),
 ('secretaria',  array['causas','inicio','estado','resumen','lapsos','orientacion','tiempo','seguridad','bitacora','validar_resumen','editar_calendario','ver_identificacion']),
 ('abogado',     array['inicio','estado','resumen','lapsos','orientacion','tiempo','seguridad']),
 ('justiciable', array['inicio','estado','resumen','lapsos','orientacion','tiempo','seguridad']),
 ('tercero',     array['inicio','orientacion','seguridad'])
) as r(rol, mods), unnest(r.mods) as m(modulo);

-- Causas del Juzgado Demo
insert into public.causas (id, tribunal, corta, materia, actora, demandada, etapa, inicio, lapso, datos) values
('DEMO-0001','Juzgado Demo de Primera Instancia en lo Civil','Arrendamiento','Cumplimiento de contrato de arrendamiento','Comercial Ejemplo, C.A.','Ana Demo','Contestación','2026-10-20',20,
 '{"evF":47,"evT":"la citación","evC":"El tribunal registró que usted fue notificado de la demanda","evCalc":"Citación consignada","lapN":"contestación","art":"344","verbT":"contestar","verbC":"responder","accC":"responderla","accC2":"responder la demanda","startLab":"Cita","startLeg":"Citación",
   "ultT":"Última actuación validada: consignación del recibo de citación. Corre el lapso de contestación.","ultC":"Lo último validado en su causa es que el tribunal registró su notificación de la demanda. Ahora corre el plazo para responderla.",
   "tl":[["Demanda presentada",1,"done"],["Admisión",31,"done"],["Citación",47,"done"],["Contestación: lapso en curso",null,"now","Responder la demanda: plazo en curso"],["Pruebas",null,"next"],["Sentencia",null,"next"]]}'),
('DEMO-0002','Juzgado Demo de Primera Instancia en lo Civil','Cobro de bolívares','Cobro de bolívares','Banco Ficticio, C.A.','Inversiones Prueba, S.R.L.','Contestación','2026-10-09',20,
 '{"evF":29,"evT":"la citación","evC":"El tribunal registró que la parte demandada fue notificada de la demanda","evCalc":"Citación consignada","lapN":"contestación","art":"344","verbT":"contestar","verbC":"responder","accC":"responderla","accC2":"responder la demanda","startLab":"Cita","startLeg":"Citación",
   "ultT":"Última actuación validada: consignación del recibo de citación. Corre el lapso de contestación.","ultC":"Lo último validado es que el tribunal registró la notificación de la parte demandada. Ahora corre el plazo para responder la demanda.",
   "tl":[["Demanda presentada",1,"done"],["Admisión",18,"done"],["Citación",29,"done"],["Contestación: lapso en curso",null,"now","Responder la demanda: plazo en curso"],["Pruebas",null,"next"],["Sentencia",null,"next"]]}'),
('DEMO-0003','Juzgado Demo de Primera Instancia en lo Civil','Compraventa','Resolución de contrato de compraventa','Constructora Muestra, C.A.','Luis Ejemplo','Promoción de pruebas','2026-10-26',15,
 '{"evF":58,"evT":"la contestación","evC":"La parte demandada respondió la demanda y el juicio quedó abierto a pruebas","evCalc":"Venció el lapso de contestación","lapN":"promoción de pruebas","art":"396","verbT":"promover pruebas","verbC":"presentar pruebas","accC":"presentar las pruebas","accC2":"presentar las pruebas","startLab":"Inicio","startLeg":"Fin de la contestación",
   "ultT":"Última actuación validada: escrito de contestación. Corre el lapso de promoción de pruebas.","ultC":"Lo último validado es que la parte demandada respondió la demanda. Ahora corre el plazo para presentar pruebas.",
   "tl":[["Demanda presentada",1,"done"],["Admisión",22,"done"],["Citación",35,"done"],["Contestación",58,"done"],["Pruebas: promoción en curso",null,"now","Presentar pruebas: plazo en curso"],["Sentencia",null,"next"]]}'),
('DEMO-0004','Juzgado Demo de Primera Instancia en lo Civil','Daños y perjuicios','Indemnización por daños y perjuicios','María Prueba','Transporte Demo, C.A.','Evacuación de pruebas','2026-10-14',30,
 '{"evF":112,"evT":"la admisión de las pruebas","evC":"El tribunal admitió las pruebas de las partes","evCalc":"Pruebas admitidas","lapN":"evacuación de pruebas","art":"400","verbT":"evacuar pruebas","verbC":"practicar las pruebas","accC":"practicar las pruebas admitidas","accC2":"practicar las pruebas","startLab":"Inicio","startLeg":"Admisión de pruebas",
   "ultT":"Última actuación validada: auto de admisión de pruebas. Corre el lapso de evacuación.","ultC":"Lo último validado es que el tribunal aceptó las pruebas. Ahora corre el plazo para practicarlas.",
   "tl":[["Demanda presentada",1,"done"],["Admisión",15,"done"],["Citación",27,"done"],["Contestación",40,"done"],["Pruebas: evacuación en curso",112,"now","Practicar las pruebas: plazo en curso"],["Sentencia",null,"next"]]}'),
('DEMO-0005','Juzgado Demo de Primera Instancia en lo Civil','Reivindicación','Acción reivindicatoria','Rosa Ficticia','Pedro Demo','Contestación','2026-11-03',20,
 '{"evF":21,"ultF":9,"evT":"la citación","evC":"El tribunal registró que la parte demandada fue notificada de la demanda","evCalc":"Citación consignada","lapN":"contestación","art":"344","verbT":"contestar","verbC":"responder","accC":"responderla","accC2":"responder la demanda","startLab":"Cita","startLeg":"Citación",
   "ultT":"Última actuación validada: auto de admisión. La consignación de la citación está pendiente de validación.","ultC":"Lo último validado es que el tribunal aceptó tramitar la demanda. La constancia de la citación todavía está en revisión.",
   "tl":[["Demanda presentada",1,"done"],["Admisión",9,"done"],["Citación",21,"done"],["Contestación: lapso en curso",null,"now","Responder la demanda: plazo en curso"],["Pruebas",null,"next"],["Sentencia",null,"next"]]}'),
('DEMO-0006','Juzgado Demo de Primera Instancia en lo Civil','Servicios','Cumplimiento de contrato de servicios','Servicios Ejemplo, C.A.','Comercio Demo, S.A.','Pendiente de citación',null,null,
 '{"evF":12,"evT":"el auto de admisión","evC":"El tribunal aceptó tramitar la demanda y ordenó notificar a la parte demandada",
   "ultT":"Última actuación validada: auto de admisión. Pendiente la citación de la parte demandada.","ultC":"Lo último validado es que el tribunal aceptó la demanda. Falta notificar a la parte demandada; el plazo para responder empieza después.",
   "tl":[["Demanda presentada",1,"done"],["Admisión",12,"done"],["Citación: pendiente",null,"now","Notificar a la parte demandada: pendiente"],["Contestación",null,"next"],["Pruebas",null,"next"],["Sentencia",null,"next"]]}');

-- Identificación de las partes (separada: solo con permiso)
insert into public.causas_identificacion (causa, actora_id, demandada_id) values
 ('DEMO-0001','J-00000000-0','V-00.000.000'),
 ('DEMO-0002','J-00000000-1','J-00000000-2'),
 ('DEMO-0003','J-00000000-3','V-00.000.003'),
 ('DEMO-0004','V-00.000.004','J-00000000-5'),
 ('DEMO-0005','V-00.000.005','V-00.000.006'),
 ('DEMO-0006','J-00000000-7','J-00000000-8');

-- Folios (la huella SHA-256 la calcula la base al guardar)
insert into public.folios (causa, numero, titulo, texto) values
 ('DEMO-0001', 1,'Libelo de demanda',E'La parte actora, Comercial Ejemplo, C.A., demanda el cumplimiento de un contrato de arrendamiento de un local comercial.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0001',14,'Anexo: contrato de arrendamiento',E'Contrato de arrendamiento entre las partes, consignado como documento fundamental de la demanda.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0001',31,'Auto de admisión',E'El Tribunal admite la demanda y ordena emplazar a la parte demandada para que dé contestación dentro de los veinte días de despacho siguientes a su citación.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0001',47,'Consignación del recibo de citación',E'En fecha 20 de octubre de 2026, el alguacil de este Juzgado consigna al expediente el recibo de citación firmado por la parte demandada.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0001',52,'Escrito de la parte demandada',E'La parte demandada consigna escrito y designa apoderado judicial para este procedimiento.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0002', 1,'Libelo de demanda',E'Banco Ficticio, C.A. demanda el cobro de una suma de dinero derivada de un contrato de préstamo.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0002',18,'Auto de admisión',E'El Tribunal admite la demanda por el procedimiento ordinario y ordena emplazar a la parte demandada para que dé contestación dentro de los veinte días de despacho siguientes a su citación.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0002',29,'Consignación del recibo de citación',E'En fecha 9 de octubre de 2026, el alguacil de este Juzgado consigna al expediente el recibo de citación firmado por la representante de la parte demandada.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0003', 1,'Libelo de demanda',E'Constructora Muestra, C.A. demanda la resolución de un contrato de compraventa de un inmueble por falta de pago del precio.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0003',22,'Auto de admisión',E'El Tribunal admite la demanda y ordena emplazar al demandado para la contestación.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0003',35,'Consignación del recibo de citación',E'El alguacil de este Juzgado consigna el recibo de citación firmado por el demandado.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0003',58,'Escrito de contestación',E'El demandado da contestación a la demanda y la rechaza en todas sus partes.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0003',60,'Diligencia de la parte actora',E'El apoderado de la parte actora solicita copias certificadas del expediente.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0004', 1,'Libelo de demanda',E'María Prueba demanda indemnización por los daños sufridos en un accidente de tránsito con un vehículo de Transporte Demo, C.A.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0004',15,'Auto de admisión',E'El Tribunal admite la demanda y ordena emplazar a la parte demandada.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0004',27,'Consignación del recibo de citación',E'El alguacil de este Juzgado consigna el recibo de citación firmado por el representante de la parte demandada.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0004',40,'Escrito de contestación',E'La parte demandada da contestación a la demanda y niega su responsabilidad en el accidente.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0004',112,'Auto de admisión de pruebas',E'El Tribunal admite las pruebas promovidas por ambas partes por no ser manifiestamente ilegales ni impertinentes.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0005', 1,'Libelo de demanda',E'Rosa Ficticia demanda la reivindicación de un inmueble que alega ocupado sin título por el demandado.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0005', 9,'Auto de admisión',E'El Tribunal admite la demanda y ordena emplazar al demandado.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0005',21,'Consignación del recibo de citación',E'En fecha 3 de noviembre de 2026, el alguacil de este Juzgado consigna el recibo de citación firmado por el demandado.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0006', 1,'Libelo de demanda',E'Servicios Ejemplo, C.A. demanda el cumplimiento de un contrato de prestación de servicios de mantenimiento.\n\nDocumento ficticio, creado solo para esta demostración.'),
 ('DEMO-0006',12,'Auto de admisión',E'El Tribunal admite la demanda y ordena la citación de la parte demandada.\n\nDocumento ficticio, creado solo para esta demostración.');

-- Resumen con folios (validación humana)
insert into public.resumen (causa, folio, orden, tecnico, claro, estado) values
 ('DEMO-0001', 1,1,'Comercial Ejemplo, C.A. demanda el cumplimiento de un contrato de arrendamiento de un local comercial.','Una empresa demandó para exigir que se cumpla un contrato de alquiler de un local.','validado'),
 ('DEMO-0001',14,2,'Se consigna como documento fundamental el contrato de arrendamiento.','La empresa entregó al tribunal el contrato de alquiler.','validado'),
 ('DEMO-0001',31,3,'Admitida la demanda, se emplaza a la demandada a contestar dentro de veinte días de despacho siguientes a su citación.','El tribunal aceptó tramitar la demanda y fijó un plazo de 20 días de despacho para responderla, contados después de la citación.','validado'),
 ('DEMO-0001',47,4,'El alguacil consigna el recibo de citación firmado por la demandada, en fecha 20/10/2026.','Quedó registrado que usted fue notificado de la demanda el 20 de octubre de 2026.','validado'),
 ('DEMO-0001',52,5,'La demandada consigna escrito y designa apoderado judicial.','Usted presentó un escrito y nombró a un abogado que la representa.','pendiente'),
 ('DEMO-0002', 1,1,'Banco Ficticio, C.A. demanda el cobro de una suma de dinero derivada de un contrato de préstamo.','Un banco demandó para cobrar el dinero de un préstamo.','validado'),
 ('DEMO-0002',18,2,'Admitida la demanda, se emplaza a la demandada a contestar dentro de los veinte días de despacho siguientes a su citación.','El tribunal aceptó tramitar la demanda y fijó un plazo de 20 días de despacho para responderla, contados después de la citación.','validado'),
 ('DEMO-0002',29,3,'El alguacil consigna el recibo de citación firmado por la representante de la demandada, en fecha 09/10/2026.','Quedó registrado que la empresa demandada fue notificada de la demanda el 9 de octubre de 2026.','validado'),
 ('DEMO-0003', 1,1,'Constructora Muestra, C.A. demanda la resolución de un contrato de compraventa de un inmueble por falta de pago del precio.','Una constructora demandó para deshacer la venta de un inmueble porque, según ella, no le pagaron el precio.','validado'),
 ('DEMO-0003',22,2,'Se admite la demanda y se ordena el emplazamiento del demandado.','El tribunal aceptó tramitar la demanda y ordenó citar al demandado.','validado'),
 ('DEMO-0003',58,3,'El demandado consigna escrito de contestación y rechaza la demanda en todas sus partes.','El demandado respondió la demanda y dijo que no está de acuerdo con lo que se le reclama.','validado'),
 ('DEMO-0003',60,4,'El apoderado de la parte actora solicita copias certificadas del expediente.','El abogado de la constructora pidió copias certificadas del expediente.','pendiente'),
 ('DEMO-0004', 1,1,'María Prueba demanda indemnización por los daños sufridos en un accidente de tránsito con un vehículo de Transporte Demo, C.A.','Una persona demandó a una empresa de transporte para que le pague los daños de un accidente.','validado'),
 ('DEMO-0004',40,2,'La demandada contesta la demanda y niega su responsabilidad en el accidente.','La empresa respondió la demanda y dijo que no es responsable del accidente.','validado'),
 ('DEMO-0004',112,3,'El tribunal admite las pruebas promovidas por ambas partes.','El tribunal aceptó las pruebas que presentaron las dos partes.','validado'),
 ('DEMO-0005', 1,1,'Rosa Ficticia demanda la reivindicación de un inmueble que alega ocupado sin título por el demandado.','Una persona demandó para recuperar una vivienda que, según ella, otra persona ocupa sin derecho.','validado'),
 ('DEMO-0005', 9,2,'Se admite la demanda y se ordena emplazar al demandado.','El tribunal aceptó tramitar la demanda.','validado'),
 ('DEMO-0005',21,3,'El alguacil consigna el recibo de citación firmado por el demandado, en fecha 03/11/2026.','Quedó registrado que el demandado fue notificado de la demanda el 3 de noviembre de 2026.','pendiente'),
 ('DEMO-0006', 1,1,'Servicios Ejemplo, C.A. demanda el cumplimiento de un contrato de prestación de servicios de mantenimiento.','Una empresa demandó para que se cumpla un contrato de servicios de mantenimiento.','validado'),
 ('DEMO-0006',12,2,'Se admite la demanda y se ordena la citación de la demandada.','El tribunal aceptó tramitar la demanda y ordenó notificar a la empresa demandada.','validado');

-- Calendario del tribunal
insert into public.calendario_sin_despacho (fecha, motivo) values ('2026-10-28','Día sin despacho (demostración)');

-- Primera entrada de la bitácora
insert into public.bitacora (accion) values ('Base de datos creada con 6 causas ficticias del Juzgado Demo');
