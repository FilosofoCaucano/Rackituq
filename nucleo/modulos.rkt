#lang racket

(require "estado.rkt" "vocabulario.rkt")
(provide (all-defined-out))

;; ----- SOPORTE PARA MÓDULOS -----

;; ejecutor.rkt instala aquí cómo se define un sufijo (no puede importarse
;; desde acá porque él ya importa este módulo)
(define definidor-de-sufijos (box #f))
(define (instalar-definidor-de-sufijos! f) (set-box! definidor-de-sufijos f))

;; repl.rkt instala aquí cómo se corre una línea de Rackituq
(define ejecutor-de-lineas (box #f))
(define (instalar-ejecutor-de-lineas! f) (set-box! ejecutor-de-lineas f))

;; Importar un módulo: si es un programa Rackituq se corre línea por línea;
;; si arranca con un paréntesis es el formato viejo, en expresiones de Racket
(define (importar-modulo ruta)
  (cond
    [(not (file-exists? ruta))
     (format "Error: No se pudo encontrar el módulo ~a" ruta)]
    [(formato-racket? ruta) (importar-modulo-racket ruta)]
    [else
     (let ([correr (unbox ejecutor-de-lineas)]
           [mod-env (make-hash)])
       (for ([linea (file->lines ruta)])
         (let ([limpia (string-trim linea)])
           (unless (or (string=? limpia "") (string-prefix? limpia ";;"))
             (correr limpia)
             (let ([nombre (nombre-definido limpia)])
               (when nombre (hash-set! mod-env nombre limpia))))))
       (hash-set! modulos (if (path? ruta) (path->string ruta) ruta) mod-env)
       (format "Módulo ~a importado correctamente" ruta))]))

;; ¿El archivo está en el formato viejo, con expresiones de Racket?
(define (formato-racket? ruta)
  (let ([primera (findf (lambda (l) (let ([t (string-trim l)])
                                      (and (non-empty-string? t) (not (string-prefix? t ";;")))))
                        (file->lines ruta))])
    (and primera (string-prefix? (string-trim primera) "("))))

;; Qué nombre define esta línea, si define alguno
(define (nombre-definido linea)
  (cond
    [(regexp-match #px"\\.en:([^.: ]+)" linea) => second]
    [(regexp-match #px"^definir\\.[a-z.]+ +([^ ]+)" linea) => second]
    [else #f]))

;; Importar un módulo del formato viejo
(define (importar-modulo-racket ruta)
  (if (file-exists? ruta)
      (let ([mod-env (make-hash)]
            ;; Cada módulo se evalúa en su propio namespace con Racket base
            [ns (make-base-namespace)])
        (with-input-from-file ruta
          (lambda ()
            (let loop ([expr (read)])
              (unless (eof-object? expr)
                ;; Los sufijos no son Racket: no se evalúan en el namespace
                (unless (and (pair? expr) (eq? (first expr) 'sufijo))
                  (eval expr ns))
                ;; Lo que el módulo define pasa a las variables de Rackituq
                (match expr
                  [`(define ,(? symbol? nombre) ,_)
                   (let ([valor (eval nombre ns)])
                     (hash-set! mod-env (symbol->string nombre) valor)
                     (hash-set! variables (symbol->string nombre) valor))]
                  ;; Los sufijos vuelven a definirse con su cuerpo en texto
                  [`(sufijo ,(? string? nombre) ,(? string? cuerpo))
                   ((unbox definidor-de-sufijos) nombre cuerpo)
                   (hash-set! mod-env nombre cuerpo)]
                  [_ (void)])
                (loop (read))))))
        (hash-set! modulos (if (path? ruta) (path->string ruta) ruta) mod-env)
        (format "Módulo ~a importado correctamente" ruta))
      (format "Error: No se pudo encontrar el módulo ~a" ruta)))

;; Una variable se guarda como palabra: `7,8,10.en:notas`. Así al recargar el
;; módulo la variable se actualiza en vez de chocar con la que ya existe
(define (linea-de-variable nombre valor)
  (cond
    [(or (and (list? valor) (empty? valor))
         (and (hash? valor) (zero? (hash-count valor))))
     (format ";; ~a está vacío: todavía no hay forma de escribirlo" nombre)]
    ;; Una lista de un solo elemento necesita .lista, o se leería como el valor suelto
    [(and (list? valor) (= (length valor) 1))
     (format "~a.lista.en:~a" (texto-de-valor (first valor)) nombre)]
    [else (format "~a.en:~a" (texto-de-valor valor) nombre)]))

;; Exportar definiciones a un módulo. El módulo es un programa Rackituq
;; normal: se puede leer, editar y correr con `correr`. Con "todo" guarda
;; todas las variables y todos los sufijos definidos
(define (exportar-a-modulo nombres ruta)
  (let ([lista (if (equal? nombres "todo")
                   (append (sort (hash-keys variables) string<?)
                           (sort (hash-keys sufijos) string<?))
                   nombres)])
    (with-output-to-file ruta #:exists 'replace
      (lambda ()
        (printf ";; Biblioteca Rackituq\n")
        (for ([nombre lista])
          (cond
            [(hash-has-key? variables nombre)
             (printf "~a\n" (linea-de-variable nombre (hash-ref variables nombre)))]
            ;; Un sufijo se guarda con su cuerpo tal como se escribió
            [(hash-has-key? sufijos nombre)
             (printf "definir.sufijo ~a ~a\n" nombre (hash-ref sufijos nombre))]
            ;; Una función hecha en Racket no tiene forma de texto
            [(hash-has-key? funciones nombre)
             (printf ";; ~a es una función de Racket: no se puede exportar como texto\n" nombre)]
            [else
             (printf ";; Error: ~a no está definido\n" nombre)])))))
  (format "Definiciones exportadas a ~a" ruta))
