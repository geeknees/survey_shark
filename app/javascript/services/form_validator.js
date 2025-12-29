// Form validation service (importmap version)
class FormValidator {
  constructor() {
    this.validators = new Map()
    this.setupDefaultValidators()
  }

  setupDefaultValidators() {
    this.addValidator('messageContent', (value) => {
      const errors = []
      if (!value || value.trim().length === 0)
        errors.push('メッセージを入力してください')
      if (value && value.length > 500)
        errors.push('メッセージは500文字以内で入力してください')
      if (value && this.containsScriptTags(value))
        errors.push('無効な文字が含まれています')
      return {
        isValid: errors.length === 0,
        errors,
        sanitizedValue: this.sanitizeInput(value)
      }
    })

    this.addValidator('age', (value) => {
      const errors = []
      const num = parseInt(value, 10)
      if (value && (isNaN(num) || num < 0 || num > 120))
        errors.push('年齢は0歳から120歳の間で入力してください')
      return {
        isValid: errors.length === 0,
        errors,
        sanitizedValue: isNaN(num) ? null : num
      }
    })

    this.addValidator('projectName', (value) => {
      const errors = []
      if (!value || value.trim().length === 0)
        errors.push('プロジェクト名を入力してください')
      if (value && value.length > 100)
        errors.push('プロジェクト名は100文字以内で入力してください')
      return {
        isValid: errors.length === 0,
        errors,
        sanitizedValue: this.sanitizeInput(value)
      }
    })

    this.addValidator(
      'customAttribute',
      (value, { required = false, maxLength = 200 } = {}) => {
        const errors = []
        if (required && (!value || value.trim().length === 0))
          errors.push('この項目は必須です')
        if (value && value.length > maxLength)
          errors.push(`${maxLength}文字以内で入力してください`)
        return {
          isValid: errors.length === 0,
          errors,
          sanitizedValue: this.sanitizeInput(value)
        }
      }
    )
  }

  addValidator(name, fn) {
    this.validators.set(name, fn)
  }
  validate(name, value, options = {}) {
    const v = this.validators.get(name)
    if (!v) throw new Error(`Validator '${name}' not found`)
    return v(value, options)
  }

  validateForm(formData) {
    const results = {}
    const allErrors = []
    Object.entries(formData).forEach(
      ([field, { validatorName, value, options = {} }]) => {
        try {
          const result = this.validate(validatorName, value, options)
          results[field] = result
          if (!result.isValid)
            allErrors.push(...result.errors.map((error) => ({ field, error })))
        } catch (_) {
          results[field] = {
            isValid: false,
            errors: ['バリデーションエラーが発生しました'],
            sanitizedValue: value
          }
        }
      }
    )
    return { isValid: allErrors.length === 0, errors: allErrors, results }
  }

  validateFormElement(element) {
    if (!element) return { isValid: true, errors: [] }
    const validatorName = element.dataset.validator
    if (!validatorName) return { isValid: true, errors: [] }
    const value = element.value
    const options = this.parseValidationOptions(element)
    return this.validate(validatorName, value, options)
  }

  parseValidationOptions(element) {
    const options = {}
    if (element.hasAttribute('required')) options.required = true
    if (element.hasAttribute('data-max-length'))
      options.maxLength = parseInt(element.dataset.maxLength, 10)
    if (element.hasAttribute('data-min-length'))
      options.minLength = parseInt(element.dataset.minLength, 10)
    return options
  }

  sanitizeInput(value) {
    if (!value || typeof value !== 'string') return value
    return value
      .trim()
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<[^>]*>/g, '')
      .replace(/javascript:/gi, '')
  }

  containsScriptTags(value) {
    return /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi.test(value)
  }

  setupRealtimeValidation(form) {
    if (!form) return
    const elements = form.querySelectorAll('[data-validator]')
    elements.forEach((el) => {
      let timeout
      const show = (result) => {
        this.clearValidationErrors(el)
        if (!result.isValid) this.displayValidationErrors(el, result.errors)
      }
      el.addEventListener('input', () => {
        clearTimeout(timeout)
        timeout = setTimeout(() => {
          show(this.validateFormElement(el))
        }, 300)
      })
      el.addEventListener('blur', () => {
        show(this.validateFormElement(el))
      })
    })
  }

  displayValidationErrors(element, errors) {
    const c = this.getOrCreateErrorContainer(element)
    c.innerHTML = ''
    errors.forEach((e) => {
      const d = document.createElement('div')
      d.classList.add('text-red-500', 'text-sm', 'mt-1')
      d.textContent = e
      c.appendChild(d)
    })
    element.classList.add('border-red-500')
  }

  clearValidationErrors(element) {
    const c = element.parentNode.querySelector('.validation-errors')
    if (c) c.innerHTML = ''
    element.classList.remove('border-red-500')
  }

  getOrCreateErrorContainer(element) {
    let c = element.parentNode.querySelector('.validation-errors')
    if (!c) {
      c = document.createElement('div')
      c.classList.add('validation-errors')
      element.parentNode.appendChild(c)
    }
    return c
  }
}

const formValidator = new FormValidator()
export default formValidator
