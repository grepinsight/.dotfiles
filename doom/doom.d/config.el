;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.

(setq user-full-name "Albert Lee"
      user-mail-address "grepinsight@gmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;;(setq doom-theme 'doom-one)
(setq doom-theme 'doom-gruvbox)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/Dropbox/vimwiki")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)


(setq projectile-tags-file-name "MYTAGS")
(setq projectile-tags-command
      "rg --files | ctags -Re --links=no -f \"%s\" %s -L -")

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(use-package! org-super-agenda
  :after org-agenda
  :init

  (setq org-agenda-custom-commands
        '(
          ("o" "My Agenda"
           (
            (todo "TODO" (
                        (org-agenda-overriding-header "\n⚡ Do Today:\n⎺⎺⎺⎺⎺⎺⎺⎺⎺")
                        (org-agenda-remove-tags t)
                        (org-agenda-prefix-format " %-2i %-15b")
                        (org-agenda-todo-keyword-format "")
                        ))
            (agenda "" (
                        (org-agenda-start-day "+0d")
                        (org-agenda-span 5)
                        (org-agenda-overriding-header "⚡ Schedule:\n⎺⎺⎺⎺⎺⎺⎺⎺⎺")
                        (org-agenda-repeating-timestamp-show-all nil)
                        (org-agenda-remove-tags t)
                        (org-agenda-prefix-format   "  %-3i  %-15b %t%s")
                        (org-agenda-todo-keyword-format " ☐ ")
                        (org-agenda-current-time-string "⮜┈┈┈┈┈┈┈ now")
                        (org-agenda-scheduled-leaders '("" ""))
                        (org-agenda-time-grid (quote ((daily today remove-match)
                                                      (0900 1200 1500 1800 2100)
                                                      "      " "┈┈┈┈┈┈┈┈┈┈┈┈┈")))
                        ))))
          ("A" "testyAlbert"
           (

            (agenda "" (
                        (org-agenda-category-icon-alist nil)
                        (org-agenda-overriding-header "⚡ Schedule:\n⎺⎺⎺⎺⎺⎺⎺⎺⎺")
                        (org-agenda-repeating-timestamp-show-all t)
                        (org-agenda-span 'day)
                        (org-habit-show-habits t)
                        (org-agenda-time-grid (quote ((daily today remove-match)
                                                      (0900 1200 1500 1800 2100)
                                                      "      " "┈┈┈┈┈┈┈┈┈┈┈┈┈")))
                        )
                    )
            (alltodo "TODO" (
                        ;; (org-agenda-overriding-header "\n⚡ Do Today:\n⎺⎺⎺⎺⎺⎺⎺⎺⎺")
                        ;; (org-agenda-remove-tags nil)
                        (org-agenda-scheduled-leaders '("Scheduled:" "Sched.%2dx:"))
                        (org-agenda-prefix-format " %i %-12:c")

                        (org-habit-graph-column 40)
                        (+org-habit-min-width 99)
                        (org-super-agenda-groups '(
                                                   (:name "Today"
                                                    :time-grid t
                                                    :date today
                                                    :scheduled today
                                                    :order 1)))
                        ))
            )
           )

          ("z" "Super zaen view"
           (
            (agenda "" (
                        (org-agenda-category-icon-alist nil)
                        (org-agenda-start-day "+0d")
                        (org-agenda-span 1)
                        (org-agenda-start-with-log-mode t)
                        (org-agenda-show-log t)
                        (org-agenda-include-inactive-timestamps t)
                        (org-super-agenda-groups
                        `(
                                (:name "Done"
                                :todo "DONE"
                                :regexp ,(concat "State \"DONE\".*" (format-time-string "%Y-%m-%d"))
                                ;; :regexp "State \"DONE\".*"
                                ;; :regexp ,(format-time-string "%Y-%m-%d")
                                :transformer (--> it (propertize it 'face '(:strike-through t :foreground "grey")))
                                :order 0
                                )
                                (:name "Clocked today"
                                :log t
                                :order 1
                                )
                                (:name "Important"
                                :tag "Important"
                                :and(:priority "A" :scheduled nil)
                                :and(:priority "A" :scheduled today)
                                :order 1)
                                (:name "Today"
                                :time-grid t
                                :date today
                                :order 2
                                )
                                (:name "Scheduled"
                                :scheduled t
                                :order 3
                                )
                                (:name "Waiting"
                                :and(:todo "WAIT" :not(:tag "work"))
                                :order 4)
                                (:auto-category t :order 3)
                                ))
                      ))
            (todo "TODO|PLAY|WAIT|LEARN" ((org-agenda-overriding-header "")
                ;; (org-agenda-property-list '("LOCATION" "TEACHER") )
                ;; (org-agenda-property-position 'where-it-fits)
                ;; (org-agenda-property-separator "|" )

                (org-agenda-span 7)
                (org-super-agenda-groups
                `((:name "Next to do"
                                :todo "NEXT"
                                :order 1)
                        (:name "Important"
                                :tag "Important"
                                :and(:priority "A" :scheduled nil)
                                :and(:priority "A" :scheduled today)
                                :order 1)
                        (:name "Due Today"
                                :deadline today
                                :order 2)
                        (:name "Habit"
                                :and(:habit t :scheduled today)
                                :and(:habit t :scheduled past)
                                :order 3)
                        (:todo "PLAY" :order 4)
                        (:name "Due Soon"
                                :deadline ,(org-read-date nil nil "+14")
                                :order 8)
                        (:name "Overdue"
                                :deadline past
                                :order 7)
                        (:name "Goals"
                                :category "goals"
                                :order 8)
                        (:name "Inbox"
                                :category "inbox"
                                :order 9)
                        (:name "Assignments"
                                :tag "assignment"
                                :order 10)
                        (:name "Projects"
                                :tag "project"
                                :order 14)
                        (:name "Emacs"
                                :tag "Emacs"
                                :order 13)
                        (:name "In-Progress"
                                :and(:todo "IN-PROGRESS" :not(:tag "ARCHIVE"))
                                :order 13)
                        (:name "QUESTION"
                        :and(:todo "QUESTION" :not(:tag "ARCHIVE"))
                        :order 13)
                        (:name "Research"
                                :tag "Research"
                                :order 15)
                        (:name "To read"
                                :tag "read"
                                :order 30)
                        (:name "To Learn"
                                :tag "learn"
                                :order 20)

                        (:order-multi (40 (:name "Done today"
                                                :and (:regexp "State \"DONE\""
                                                                :log t))
                                        (:name "Clocked today"
                                                :log t
                                                )))
                        (:name "Waiting"
                                :and(:todo "WAIT" :not(:tag "work"))
                                :order 20)
                        (:name "Waiting/Work"
                                :and(:todo "WAIT" :tag "work")
                                :order 20)
                        (:name "trivial"
                                :priority<= "C"
                                :tag ("trivial" "unimportant")
                                :todo ("MAYBE" )
                                :order 90)
                        (:discard (:tag ("Chore" "Routine" "Daily")))
                        ))
                ))
                )

               )
          ("u" "Unscheduled TODO"
           ((todo ""
                ((org-agenda-overriding-header "\nUnscheduled TODO")
                 (org-agenda-skip-function '(org-agenda-skip-entry-if 'timestamp))))) nil nil)
          ))


  :config
  (org-super-agenda-mode)
)

; Org mode
(after! org

  (defun my/dx-describe-get (stuff type)
    "dx describe something and extract field using jq"
    (interactive)
    (substring
      (shell-command-to-string (format "dx describe %s --json | jq -r .%s" stuff type))
      0 -1
     )
    )

  (defun my/dx-id-to-url (stuff)
    "convert dx-id to url"
    (interactive)
    (cond
     ((string-match "^project-" stuff) (replace-regexp-in-string "project-" "projects/" stuff))
     ((string-match "^analysis-" stuff) (format "%s/monitor/%s"
                                                (my/dx-id-to-url (my/dx-describe-get stuff "project"))
                                                (replace-regexp-in-string "analysis-" "analysis/" stuff)))

     ((string-match "^file-" stuff) (format "%s/data/?scope=project&id.values=%s"
                                            (my/dx-id-to-url (my/dx-describe-get stuff "project"))
                                            stuff))
     (t nil)
          )
    )

  (defun my/translate-es-en (stuff)
    "google translate"
    (interactive)
    (format
     "https://translate.google.com/#view=home&op=translate&sl=es&tl=en&text=%s"
     (url-encode-url stuff)
     )
    )
  (defun my/translate-en-es (stuff)
    "google translate"
    (interactive)
    (format
     "https://translate.google.com/#view=home&op=translate&sl=en&tl=es&text=%s"
     (url-encode-url stuff)
     )
    )

  (defun my/translate (stuff)
    "google translate"
    (interactive)
    (format "http://translate.google.com/?source=osdd#auto|auto|%s" (url-encode-url stuff)))

  ; link abbreviations
  (setq org-link-abbrev-alist
        '(
          ("google"  . "http://www.google.com/search?q=")
          ("gmap"    . "http://maps.google.com/maps?q=%s")
          ("dx"      . "https://platform.dnanexus.com/panx/%(my/dx-id-to-url)")
          ("spanish" . "https://www.spanishdict.com/translate/%s")
          ("gt_es"   . "%(my/translate-es-en)")
          ("en_es"   . "%(my/translate-en-es)")
          ("translate"   . "%(my/translate)")
          )
        )

  (setq org-columns-default-format "%TODO %7EFFORT %10TIME_SPENT{:} %PRIORITY %100ITEM 100%TAGS")
  (customize-set-value
    'org-agenda-category-icon-alist
    `(
      ("work" "~/.dotfiles/icons/money-bag.svg" nil nil :ascent center)
      ("chore" "~/.dotfiles/icons/loop.svg" nil nil :ascent center)
      ("events" "~/.dotfiles/icons/calendar.svg" nil nil :ascent center)
      ("todo" "~/.dotfiles/icons/checklist.svg" nil nil :ascent center)
      ("exercise" "~/.dotfiles/icons/walk.svg" nil nil :ascent center)
      ("solution" "~/.dotfiles/icons/solution.svg" nil nil :ascent center)
      ))

  (setq org-todo-keywords
        '((sequence
           "TODO(t)"  ; A task that needs doing & is ready to do
           "NEXT(n)"
           "IN-PROGRESS(p)"
           "WAIT(w)"
           "MAYBE(b)"
           "PROJ(p)"  ; A project, which usually contains other tasks
           "STRT(s)"  ; A task that is in progress
           "WAIT(w)"  ; Something external is holding up this task
           "HOLD(h)"  ; This task is paused/on hold because of me
           "|"
           "DONE(d!)"  ; Task successfully completed
           "CANCELLED(c)"
           "KILL(k)") ; Task was cancelled, aborted or is no longer applicable
          (sequence
           "MEET(m)"   ; meeting someone
           "PLAY(P)"   ; play
           "|"
           "MET(M)"    ; met someone
           )
          (sequence
           "LEARN(l)"  ; learn something
           "|"
           "LEARNED(L)"; learned something
           )
          (sequence
           "PROPOSED(o)"   ; proposed an idea
           "|"
           "REJECT(R@)"   ; play
           )
          (sequence
           "CALL(C)"   ; A task that needs doing
           "|"
           "CALLED(F)"
           )
          (sequence
           "QUESTION(q)"   ; A task that needs doing
           "|"
           "ANSWERED(a)"
           )
          (sequence
           "REPEAT(r)"   ; A task that needs repeating
           "|"
           "DONE"
           )
          (sequence
           "[ ](T)"   ; A task that needs doing
           "[-](S)"   ; Task is in progress
           "[?](W)"   ; Task is being held up or paused
           "|"
           "[X](D)")
          ) ; Task was completed
        )

  (setq org-todo-keyword-faces
        '(
            ("CALL" . "yellow")
            ("PLAY" . "blue")
            ("[-]" . +org-todo-active)
            ("STRT" . +org-todo-active)
            ("[?]" . +org-todo-onhold)
            ("WAIT" . +org-todo-onhold)
            ("HOLD" . +org-todo-onhold)
            ("PROJ" . +org-todo-project)
          )
        )

  (setq org-capture-templates
        (quote (
                ("t" "Personal todo" entry (file+datetree +org-capture-todo-file)
                 "* TODO %?\n%i\n" :prepend nil :clock-in t :clock-resume t)
                ("r" "respond" entry (file +org-capture-todo-file)
                 "* NEXT Respond to %:from on %:subject\nSCHEDULED: %t\n%U\n%a\n" :clock-in t :clock-resume t :immediate-finish t)
                ("n" "Personal notes" entry
                 (file+headline +org-capture-notes-file "Inbox")
                 "* %u %?\n%i\n%a" :prepend t)
                ("j" "Journal" entry
                 (file+olp+datetree +org-capture-journal-file)
                 "* %U %?\n%i\n%a" :prepend t)
                ("o" "topic" entry (file "~/Dropbox/vimwiki/personal/topics.org")
                 "*** %? \n%U\n")
                ("k" "knowledge" entry (file "~/Dropbox/vimwiki/personal/topics.org")
                 "*** %? \n%U\n%a\n")
                ("j" "Journal" entry (file+datetree "~/Dropbox/vimwiki/personal/kanban.org")
                 "** %?\n%U\n")
                ("t" "Journal_todo" entry (file+datetree "~/Dropbox/vimwiki/personal/kanban.org")
                 "** TODO %?\n%U\n")
                ("w" "WorkJournal" entry (file+datetree "~/Dropbox/vimwiki/personal/work.org")
                 "** %?\n%U\n")
                ("m" "Meeting" entry (file "~/Dropbox/vimwiki/personal/work.org")
                 "** MEETING with %? :meeting:\n%U" )
                ("p" "Phone call" entry (file "~/Dropbox/vimwiki/personal/kanban.org")
                 "** PHONE %? :PHONE:\n%U\n%^{Tidbit type|quote|zinger|one-liner|textlet}\n%^{Name}")
                ("d" "Definitions" entry (file "~/Dropbox/vimwiki/personal/Definitions.org")
                 "**  %?\n")
                ("h" "Habit" entry (file "~/Dropbox/vimwiki/personal/kanban.org")
                 "** NEXT %?\n%U\n%a\nSCHEDULED: %(format-time-string \"%<<%Y-%m-%d %a .+1d/3d>>\")\n:PROPERTIES:\n:STYLE: habit\n:REPEAT_TO_STATE: NEXT\n:END:\n")
                ("Pb" "(Protocol bookmark)" entry (file+datetree +org-capture-todo-file)
                 "* %:description \nCaptured at %U\n[[%:link][%:description]]\n%?\n%:initial\n")
                )
               )
        )


  ; org-roam export
  (defun my/org-roam--backlinks-list-with-content (file)
    (with-temp-buffer
      (if-let* ((backlinks (org-roam--get-backlinks file))
                (grouped-backlinks (--group-by (nth 0 it) backlinks)))
          (progn
            (insert (format "\n\n* %d Backlinks\n"
                            (length backlinks)))
            (dolist (group grouped-backlinks)
              (let ((file-from (car group))
                    (bls (cdr group)))
                (insert (format "** [[file:%s][%s]]\n"
                                file-from
                                (org-roam--get-title-or-slug file-from)))
                (dolist (backlink bls)
                  (pcase-let ((`(,file-from _ ,props) backlink))
                    (insert (s-trim (s-replace "\n" " " (plist-get props :content))))
                    (insert "\n\n")))))))
      (buffer-string)))

    (defun my/org-export-preprocessor (backend)
      (let ((links (my/org-roam--backlinks-list-with-content (buffer-file-name))))
        (unless (string= links "")
          (save-excursion
            (goto-char (point-max))
            (insert (concat "\n* Backlinks\n") links)))))

    (add-hook 'org-export-before-processing-hook 'my/org-export-preprocessor)


)

;; Hide backlinks buffer by default.
(after! org-roam
  (setq +org-roam-open-buffer-on-find-file nil)
)

; Special Tags
(setq org-tags-exclude-from-inheritance '("transcript"))

; Org-Roam Related
(setq org-roam-directory "~/Dropbox/vimwiki/personal/")
(setq org-roam-index-file "~/Dropbox/vimwiki/personal/index.org")

(map! :map evil-normal-state-map "ㅗ" 'evil-backward-char) ;; h
(map! :map evil-normal-state-map "ㅓ" 'evil-next-line) ;; j
(map! :map evil-normal-state-map "ㅏ" 'evil-previous-line) ;; k
(map! :map evil-normal-state-map "ㅣ" 'evil-forward-char) ;; l

(map! :map evil-org-agenda-mode-map "sd" 'org-agenda-toggle-deadlines)
(map! :map evil-normal-state-map "ㅁ" 'evil-append)
(map! :map evil-normal-state-map "S-ㅁ" 'evil-append-line)
(map! :map evil-normal-state-map "ㅐ" 'evil-open-below) ;; o
(map! :map evil-normal-state-map "ㅒ" 'evil-open-above) ;; O

(map! "C-c a" #'org-agenda)
(map! "C-c e" #'treemacs)
(map! "C-c c" #'org-capture)
(map! "C-c l" #'org-store-link)
(map! "C-c n i" #'org-roam-jump-to-index)
(map! "C-c n r" #'helm-bibtex)
(map! "C-c n g" #'counsel-google)
(map! "C-c n t "(lambda() (interactive)(find-file "~/Dropbox/vimwiki/personal/todo.org")))
(map! "C-c n i"(lambda() (interactive)(find-file "~/Dropbox/vimwiki/personal/inbox.org")))
(map! :n "j" #'evil-next-visual-line
      :n "k" #'evil-previous-visual-line)

(use-package! org-roam-server
  :ensure t
  :config
  (setq org-roam-server-host "127.0.0.1"
        org-roam-server-port 8080
        org-roam-server-export-inline-images t
        org-roam-server-authenticate nil
        org-roam-server-network-poll t
        org-roam-server-network-arrows nil
        org-roam-server-network-label-truncate t
        org-roam-server-network-label-truncate-length 60
        org-roam-server-network-label-wrap-length 20))

(require 'org-roam-protocol)

(use-package! org-rifle
  :bind
  ("C-c r" . helm-org-rifle)
)

(use-package! org-journal
  :bind
  ("C-c n j" . org-journal-new-entry)
  :custom
  (org-journal-date-prefix "#+TITLE: ")
  (org-journal-file-format "%Y-%m-%d.org")
  (org-journal-dir "~/Dropbox/vimwiki/personal")
  (org-journal-date-format "%A, %d %B %Y"))

(setq org-download-image-dir "~/Dropbox/vimwiki/personal/images/")

(use-package! org-download
  :after org
  :bind
  (:map org-mode-map
        (("s-Y" . org-download-screenshot)
         ("s-y" . org-download-yank))))

(use-package! org-roam-bibtex
  :after org-roam
  :hook (org-roam-mode . org-roam-bibtex-mode)
  :bind (:map org-mode-map
         (("C-c n a" . orb-note-actions))))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages (quote (ox-hugo org-roam-server))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:background "#21242b")))))

; Org-Ref
(use-package! org-ref
    :config
    (setq
         org-ref-completion-library 'org-ref-ivy-cite
         org-ref-get-pdf-filename-function 'org-ref-get-pdf-filename-helm-bibtex
         org-ref-default-bibliography (list "~/Dropbox/vimwiki/personal/references.bib")
         org-ref-bibliography-notes "~/Dropbox/vimwiki/personal/notes.org"
         org-ref-note-title-format "* TODO %y - %t\n :PROPERTIES:\n  :Custom_ID: %k\n  :NOTER_DOCUMENT: %F\n :ROAM_KEY: cite:%k\n  :AUTHOR: %9a\n  :JOURNAL: %j\n  :YEAR: %y\n  :VOLUME: %v\n  :PAGES: %p\n  :DOI: %D\n  :URL: %U\n :END:\n\n"
         org-ref-notes-directory "~/Dropbox/vimwiki/personal"
         org-ref-pdf-directory "~/Dropbox/vimwiki/personal/papers"
         org-ref-notes-function 'orb-edit-notes
    ))


; bibtex completion
(setq
 bibtex-completion-notes-path "~/Dropbox/vimwiki/personal"
 bibtex-completion-bibliography "~/Dropbox/vimwiki/personal/references.bib"
 bibtex-completion-pdf-field "file"
 bibtex-completion-library-path "~/Dropbox/vimwiki/personal/papers"
 bibtex-completion-notes-template-multiple-files
 (concat
  "#+TITLE: ${title}\n"
  "#+ROAM_KEY: cite:${=key=}\n"
  "* TODO Notes\n"
  ":PROPERTIES:\n"
  ":Custom_ID: ${=key=}\n"
  ":NOTER_DOCUMENT: %(orb-process-file-field \"${=key=}\")\n"
  ":AUTHOR: ${author-abbrev}\n"
  ":JOURNAL: ${journaltitle}\n"
  ":DATE: ${date}\n"
  ":YEAR: ${year}\n"
  ":DOI: ${doi}\n"
  ":URL: ${url}\n"
  ":END:\n\n"
  )
 )


(use-package! deft
  :after org
  :bind
  ("C-c n d" . deft)
  :custom
  (deft-use-filter-string-for-filename t)
  (deft-default-extension "org")
  (deft-directory "~/Dropbox/vimwiki/personal/"))


(use-package! ox-hugo
  :ensure t            ;Auto-install the package from Melpa (optional)
  :after ox)

;; active Babel languages
(org-babel-do-load-languages
 'org-babel-load-languages
 '((gnuplot . t)))

(setq org-latex-pdf-process
      (quote
       ("pdflatex %f"
        "biber %b"
        "pdflatex %f"
        "pdflatex %f")
       )
      )

(defun org-babel-tangle-append ()
  "Append source code block at point to its tangle file.
The command works like `org-babel-tangle' with prefix arg
but `delete-file' is ignored."
  (interactive)
  (cl-letf (((symbol-function 'delete-file) #'ignore))
    (org-babel-tangle '(4))))

(defun org-babel-tangle-append-setup ()
  "Add key-binding C-c C-v C-t for `org-babel-tangle-append'."
  (org-defkey org-mode-map (kbd "C-c C-v +") 'org-babel-tangle-append))

(add-hook 'org-mode-hook #'org-babel-tangle-append-setup)


;; Icalendar stuff
;; export scheduled todo items
(setq org-icalendar-use-scheduled '(event-if-todo event-if-not-todo))
(setq org-icalendar-use-deadline '(event-if-todo))


(defun save-all ()
    (interactive)
    (save-some-buffers t))

(add-hook 'focus-out-hook 'save-all)


(add-hook 'post-command-hook #'org-roam--maybe-update-buffer nil t)


;; datetree jump
(defun al/goto-today-diary()
    (interactive)
    (goto-char (org-find-exact-headline-in-buffer (format-time-string "%Y-%m-%d %A") (find-file "~/Dropbox/vimwiki/personal/todo.org")))
    (org-show-entry)
    (outline-show-subtree)
    )
(map! "C-c d" 'al/goto-today-diary)
(setq org-agenda-clockreport-parameter-plist '(:stepskip0 t :link t :maxlevel 4 :fileskip0 t))

(exec-path-from-shell-initialize)


(setq org-ditaa-jar-path "~/src/ditaa/ditaa0_9/ditaa0_9.jar")
