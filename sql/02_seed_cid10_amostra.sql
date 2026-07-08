-- ═══════════════════════════════════════════════════════════════════════════
-- SEED DE AMOSTRA — CID-10 (códigos mais comuns em SST)
-- Para a base completa (~14 mil códigos), importe o CSV oficial do DATASUS
-- pela interface do Supabase: Table Editor → esg_cid10 → Insert → Import CSV
-- Fonte oficial: http://www2.datasus.gov.br/cid10/V2008/cid10.htm
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.esg_cid10 (codigo, descricao) values
  ('S00',   'Traumatismo superficial da cabeça'),
  ('S01',   'Ferimento da cabeça'),
  ('S06',   'Traumatismo intracraniano'),
  ('S20',   'Traumatismo superficial do tórax'),
  ('S30',   'Traumatismo superficial do abdome, do dorso e da pelve'),
  ('S40',   'Traumatismo superficial do ombro e do braço'),
  ('S42',   'Fratura do ombro e do braço'),
  ('S50',   'Traumatismo superficial do cotovelo e do antebraço'),
  ('S52',   'Fratura do antebraço'),
  ('S52.5', 'Fratura da extremidade distal do rádio'),
  ('S60',   'Traumatismo superficial do punho e da mão'),
  ('S61',   'Ferimento do punho e da mão'),
  ('S62',   'Fratura ao nível do punho e da mão'),
  ('S63',   'Luxação, entorse e distensão das articulações e dos ligamentos ao nível do punho e da mão'),
  ('S70',   'Traumatismo superficial do quadril e da coxa'),
  ('S80',   'Traumatismo superficial da perna'),
  ('S82',   'Fratura da perna, incluindo tornozelo'),
  ('S90',   'Traumatismo superficial do tornozelo e do pé'),
  ('S93',   'Luxação, entorse e distensão das articulações e dos ligamentos ao nível do tornozelo e do pé'),
  ('T14',   'Traumatismo de região não especificada do corpo'),
  ('T15',   'Corpo estranho na parte externa do olho'),
  ('M54',   'Dorsalgia'),
  ('M54.5', 'Dor lombar baixa'),
  ('M75',   'Lesões do ombro'),
  ('M77',   'Outras entesopatias'),
  ('W01',   'Queda no mesmo nível por escorregão, tropeção ou passos em falsos [traspés]'),
  ('W19',   'Queda sem especificação'),
  ('V23',   'Motociclista traumatizado em colisão com um automóvel [carro], "pick up" ou caminhonete'),
  ('V29',   'Motociclista traumatizado em outros acidentes de transporte e em acidentes de transporte não especificados'),
  ('Z04.2', 'Exame e observação após acidente de trabalho')
on conflict (codigo) do update set descricao = excluded.descricao;
