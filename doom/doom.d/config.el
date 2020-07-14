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
(setq doom-theme 'doom-one)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/Dropbox/vimwiki")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)


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
           ((todo "TODO" (
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

          ("z" "Super zaen view"
               ((agenda "" ((org-agenda-span 'day)
                                            (org-agenda-property-list '("LOCATION" "TEACHER") )
                                            (org-agenda-property-position 'where-it-fits)
                                            (org-agenda-property-separator "|" )

                      (org-super-agenda-groups
                       '((:name "Today"
                                :time-grid t
                                :date today
                                :todo "TODAY"
                                :scheduled today
                                :order 1
                                )))))
                (alltodo "" ((org-agenda-overriding-header "")
                       (org-agenda-property-list '("LOCATION" "TEACHER") )
                       (org-agenda-property-position 'where-it-fits)
                       (org-agenda-property-separator "|" )

                       (org-super-agenda-groups
                        '((:name "Next to do"
                                 :todo "NEXT"
                                 :order 1)
                          (:name "Important"
                                 :tag "Important"
                                 :priority "A"
                                 :order 6)
                          (:name "Due Today"
                                 :deadline today
                                 :order 2)
                          (:name "Habit"
                                 :and(:habit t :scheduled today)
                                 :order 2)
                          (:name "Due Soon"
                                 :deadline future
                                 :order 8)
                          (:name "Overdue"
                                 :deadline past
                                 :order 7)
                          (:name "Assignments"
                                 :tag "assignment"
                                 :order 10)
                          (:name "Issues"
                                 :tag "issue"
                                 :order 12)
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
                       )))

         )
        ("u" "Unscheduled TODO"
         ((todo ""
                ((org-agenda-overriding-header "\nUnscheduled TODO")
                 (org-agenda-skip-function '(org-agenda-skip-entry-if 'timestamp)))))
         nil
         nil)))
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
     ((string-match "^analysis-" stuff)
      (format "%s/monitor/%s" (my/dx-id-to-url (my/dx-describe-get stuff "project")) (replace-regexp-in-string "analysis-" "analysis/" stuff))
      )
     (t nil)
          )
    )
  ; link abbreviations
  (setq org-link-abbrev-alist
        '(
          ("google" . "http://www.google.com/search?q=")
          ("gmap"   . "http://maps.google.com/maps?q=%s")
          ("dx"     . "https://platform.dnanexus.com/panx/%(my/dx-id-to-url)")
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
           "MIGRATED(m)"
           "CANCELLED(c)"
           "DONE(d)"  ; Task successfully completed
           "KILL(k)") ; Task was cancelled, aborted or is no longer applicable
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
                ("t" "Personal todo" entry
                 (file+headline +org-capture-todo-file "Inbox")
                 "* [ ] %?\n%i\n%a" :prepend t)
                ("n" "Personal notes" entry
                 (file+headline +org-capture-notes-file "Inbox")
                 "* %u %?\n%i\n%a" :prepend t)
                ("j" "Journal" entry
                 (file+olp+datetree +org-capture-journal-file)
                 "* %U %?\n%i\n%a" :prepend t)
                ("o" "topic" entry (file "~/Dropbox/vimwiki/topics.org")
                 "*** %? \n%U\n")
                ("k" "knowledge" entry (file "~/Dropbox/vimwiki/topics.org")
                 "*** %? \n%U\n%a\n")
                ("j" "Journal" entry (file+datetree "~/Dropbox/vimwiki/kanban.org")
                 "** %?\n%U\n")
                ("t" "Journal_todo" entry (file+datetree "~/Dropbox/vimwiki/kanban.org")
                 "** TODO %?\n%U\n")
                ("w" "WorkJournal" entry (file+datetree "~/Dropbox/vimwiki/work.org")
                 "** %?\n%U\n")
                ("m" "Meeting" entry (file "~/Dropbox/vimwiki/work.org")
                 "** MEETING with %? :meeting:\n%U" )
                ("p" "Phone call" entry (file "~/Dropbox/vimwiki/kanban.org")
                 "** PHONE %? :PHONE:\n%U\n%^{Tidbit type|quote|zinger|one-liner|textlet}\n%^{Name}")
                ("d" "Definitions" entry (file "~/Dropbox/vimwiki/Definitions.org")
                 "**  %?\n")
                ("h" "Habit" entry (file "~/Dropbox/vimwiki/kanban.org")
                 "** NEXT %?\n%U\n%a\nSCHEDULED: %(format-time-string \"%<<%Y-%m-%d %a .+1d/3d>>\")\n:PROPERTIES:\n:STYLE: habit\n:REPEAT_TO_STATE: NEXT\n:END:\n")
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

; Org-Roam Related
(setq org-roam-directory "~/Dropbox/vimwiki/")
(setq org-roam-index-file "~/Dropbox/vimwiki/index.org")

(map! "C-c n i" #'org-roam-jump-to-index)
(map! "C-c n r" #'helm-bibtex)
(map! "C-c n g" #'counsel-google)
(map! "C-c n t "(lambda() (interactive)(find-file "~/Dropbox/vimwiki/todo.org")))

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
  (org-journal-dir "~/Dropbox/vimwiki")
  (org-journal-date-format "%A, %d %B %Y"))

(setq org-download-image-dir "~/Dropbox/vimwiki/images/")

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
         org-ref-default-bibliography (list "~/Dropbox/vimwiki/references.bib")
         org-ref-bibliography-notes "~/Dropbox/vimwiki/notes.org"
         org-ref-note-title-format "* TODO %y - %t\n :PROPERTIES:\n  :Custom_ID: %k\n  :NOTER_DOCUMENT: %F\n :ROAM_KEY: cite:%k\n  :AUTHOR: %9a\n  :JOURNAL: %j\n  :YEAR: %y\n  :VOLUME: %v\n  :PAGES: %p\n  :DOI: %D\n  :URL: %U\n :END:\n\n"
         org-ref-notes-directory "~/Dropbox/vimwiki"
         org-ref-pdf-directory "~/Dropbox/vimwiki/papers"
         org-ref-notes-function 'orb-edit-notes
    ))


; bibtex completion
(setq
 bibtex-completion-notes-path "~/Dropbox/vimwiki"
 bibtex-completion-bibliography "~/Dropbox/vimwiki/references.bib"
 bibtex-completion-pdf-field "file"
 bibtex-completion-library-path "~/Dropbox/vimwiki/papers"
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
  (deft-directory "~/Dropbox/vimwiki/"))


(use-package! ox-hugo
  :ensure t            ;Auto-install the package from Melpa (optional)
  :after ox)


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