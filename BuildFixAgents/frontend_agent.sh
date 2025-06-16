#!/bin/bash
# Frontend Agent - Generates UI components, forms, and frontend scaffolding
# Part of the ZeroDev/BuildFixAgents Multi-Agent System

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_STATE="$SCRIPT_DIR/state/frontend"
mkdir -p "$FRONTEND_STATE/components" "$FRONTEND_STATE/pages" "$FRONTEND_STATE/styles"

# Source logging if available
if [[ -f "$SCRIPT_DIR/enhanced_logging_system.sh" ]]; then
    source "$SCRIPT_DIR/enhanced_logging_system.sh"
else
    log_event() { echo "[$1] $2: $3"; }
fi

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Banner
show_banner() {
    echo -e "${BOLD}${PURPLE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${PURPLE}║         Frontend Agent v1.0            ║${NC}"
    echo -e "${BOLD}${PURPLE}╚════════════════════════════════════════╝${NC}"
}

# Detect frontend framework
detect_framework() {
    local framework="vanilla"
    
    if [[ -f "package.json" ]]; then
        if grep -q "\"react\"" package.json 2>/dev/null; then
            framework="react"
        elif grep -q "\"vue\"" package.json 2>/dev/null; then
            framework="vue"
        elif grep -q "\"@angular/core\"" package.json 2>/dev/null; then
            framework="angular"
        elif grep -q "\"svelte\"" package.json 2>/dev/null; then
            framework="svelte"
        elif grep -q "\"next\"" package.json 2>/dev/null; then
            framework="nextjs"
        fi
    fi
    
    echo "$framework"
}

# Generate React component
generate_react_component() {
    local name="$1"
    local type="${2:-functional}"
    local output_dir="${3:-src/components}"
    
    mkdir -p "$output_dir"
    
    log_event "INFO" "FRONTEND" "Generating React component: $name"
    
    if [[ "$type" == "functional" ]]; then
        cat > "$output_dir/${name}.jsx" << EOF
import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import './${name}.css';

const ${name} = ({ title, children, ...props }) => {
  const [isLoading, setIsLoading] = useState(false);
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    // Component initialization
    return () => {
      // Cleanup
    };
  }, []);

  const handleClick = () => {
    // Handle click event
    console.log('${name} clicked');
  };

  if (isLoading) {
    return <div className="${name}-loading">Loading...</div>;
  }

  if (error) {
    return <div className="${name}-error">{error.message}</div>;
  }

  return (
    <div className="${name}" {...props}>
      {title && <h2 className="${name}-title">{title}</h2>}
      <div className="${name}-content">
        {children}
      </div>
      <button 
        className="${name}-button"
        onClick={handleClick}
        type="button"
      >
        Click me
      </button>
    </div>
  );
};

${name}.propTypes = {
  title: PropTypes.string,
  children: PropTypes.node,
};

${name}.defaultProps = {
  title: '',
  children: null,
};

export default ${name};
EOF
    else
        # Class component
        cat > "$output_dir/${name}.jsx" << EOF
import React, { Component } from 'react';
import PropTypes from 'prop-types';
import './${name}.css';

class ${name} extends Component {
  constructor(props) {
    super(props);
    this.state = {
      isLoading: false,
      data: null,
      error: null,
    };
  }

  componentDidMount() {
    // Component initialization
  }

  componentWillUnmount() {
    // Cleanup
  }

  handleClick = () => {
    // Handle click event
    console.log('${name} clicked');
  };

  render() {
    const { title, children, ...props } = this.props;
    const { isLoading, error } = this.state;

    if (isLoading) {
      return <div className="${name}-loading">Loading...</div>;
    }

    if (error) {
      return <div className="${name}-error">{error.message}</div>;
    }

    return (
      <div className="${name}" {...props}>
        {title && <h2 className="${name}-title">{title}</h2>}
        <div className="${name}-content">
          {children}
        </div>
        <button 
          className="${name}-button"
          onClick={this.handleClick}
          type="button"
        >
          Click me
        </button>
      </div>
    );
  }
}

${name}.propTypes = {
  title: PropTypes.string,
  children: PropTypes.node,
};

${name}.defaultProps = {
  title: '',
  children: null,
};

export default ${name};
EOF
    fi
    
    # Generate CSS
    cat > "$output_dir/${name}.css" << EOF
.${name} {
  padding: 1rem;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  background-color: #ffffff;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.${name}-title {
  margin: 0 0 1rem 0;
  font-size: 1.5rem;
  color: #333333;
}

.${name}-content {
  margin-bottom: 1rem;
}

.${name}-button {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  background-color: #007bff;
  color: white;
  font-size: 1rem;
  cursor: pointer;
  transition: background-color 0.3s ease;
}

.${name}-button:hover {
  background-color: #0056b3;
}

.${name}-button:active {
  background-color: #004085;
}

.${name}-loading,
.${name}-error {
  padding: 1rem;
  text-align: center;
}

.${name}-error {
  color: #dc3545;
}
EOF
    
    # Generate test
    cat > "$output_dir/${name}.test.jsx" << EOF
import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import '@testing-library/jest-dom';
import ${name} from './${name}';

describe('${name}', () => {
  it('renders without crashing', () => {
    render(<${name} />);
  });

  it('renders title when provided', () => {
    const title = 'Test Title';
    render(<${name} title={title} />);
    expect(screen.getByText(title)).toBeInTheDocument();
  });

  it('renders children', () => {
    const childText = 'Child content';
    render(<${name}><p>{childText}</p></${name}>);
    expect(screen.getByText(childText)).toBeInTheDocument();
  });

  it('handles click event', () => {
    const consoleSpy = jest.spyOn(console, 'log');
    render(<${name} />);
    
    const button = screen.getByRole('button');
    fireEvent.click(button);
    
    expect(consoleSpy).toHaveBeenCalledWith('${name} clicked');
    consoleSpy.mockRestore();
  });
});
EOF
    
    log_event "SUCCESS" "FRONTEND" "React component generated: $name"
}

# Generate form component
generate_form_component() {
    local framework="${1:-react}"
    local form_name="${2:-ContactForm}"
    local output_dir="${3:-src/components/forms}"
    
    mkdir -p "$output_dir"
    
    log_event "INFO" "FRONTEND" "Generating form component: $form_name"
    
    case "$framework" in
        react)
            generate_react_form "$form_name" "$output_dir"
            ;;
        vue)
            generate_vue_form "$form_name" "$output_dir"
            ;;
        *)
            generate_vanilla_form "$form_name" "$output_dir"
            ;;
    esac
}

# Generate React form
generate_react_form() {
    local name="$1"
    local output_dir="$2"
    
    cat > "$output_dir/${name}.jsx" << 'EOF'
import React, { useState } from 'react';
import PropTypes from 'prop-types';
import './ContactForm.css';

const ContactForm = ({ onSubmit, initialValues = {} }) => {
  const [formData, setFormData] = useState({
    name: initialValues.name || '',
    email: initialValues.email || '',
    subject: initialValues.subject || '',
    message: initialValues.message || '',
  });

  const [errors, setErrors] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const validateForm = () => {
    const newErrors = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Name is required';
    }

    if (!formData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      newErrors.email = 'Email is invalid';
    }

    if (!formData.subject.trim()) {
      newErrors.subject = 'Subject is required';
    }

    if (!formData.message.trim()) {
      newErrors.message = 'Message is required';
    } else if (formData.message.length < 10) {
      newErrors.message = 'Message must be at least 10 characters';
    }

    return newErrors;
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value,
    }));
    
    // Clear error for this field
    if (errors[name]) {
      setErrors(prev => ({
        ...prev,
        [name]: '',
      }));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    const validationErrors = validateForm();
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors);
      return;
    }

    setIsSubmitting(true);
    try {
      await onSubmit(formData);
      // Reset form on success
      setFormData({
        name: '',
        email: '',
        subject: '',
        message: '',
      });
    } catch (error) {
      console.error('Form submission error:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form className="contact-form" onSubmit={handleSubmit}>
      <div className="form-group">
        <label htmlFor="name">Name *</label>
        <input
          type="text"
          id="name"
          name="name"
          value={formData.name}
          onChange={handleChange}
          className={errors.name ? 'error' : ''}
          disabled={isSubmitting}
        />
        {errors.name && <span className="error-message">{errors.name}</span>}
      </div>

      <div className="form-group">
        <label htmlFor="email">Email *</label>
        <input
          type="email"
          id="email"
          name="email"
          value={formData.email}
          onChange={handleChange}
          className={errors.email ? 'error' : ''}
          disabled={isSubmitting}
        />
        {errors.email && <span className="error-message">{errors.email}</span>}
      </div>

      <div className="form-group">
        <label htmlFor="subject">Subject *</label>
        <input
          type="text"
          id="subject"
          name="subject"
          value={formData.subject}
          onChange={handleChange}
          className={errors.subject ? 'error' : ''}
          disabled={isSubmitting}
        />
        {errors.subject && <span className="error-message">{errors.subject}</span>}
      </div>

      <div className="form-group">
        <label htmlFor="message">Message *</label>
        <textarea
          id="message"
          name="message"
          rows="5"
          value={formData.message}
          onChange={handleChange}
          className={errors.message ? 'error' : ''}
          disabled={isSubmitting}
        />
        {errors.message && <span className="error-message">{errors.message}</span>}
      </div>

      <button 
        type="submit" 
        className="submit-button"
        disabled={isSubmitting}
      >
        {isSubmitting ? 'Sending...' : 'Send Message'}
      </button>
    </form>
  );
};

ContactForm.propTypes = {
  onSubmit: PropTypes.func.isRequired,
  initialValues: PropTypes.shape({
    name: PropTypes.string,
    email: PropTypes.string,
    subject: PropTypes.string,
    message: PropTypes.string,
  }),
};

export default ContactForm;
EOF
    
    # Form CSS
    cat > "$output_dir/${name}.css" << 'EOF'
.contact-form {
  max-width: 600px;
  margin: 0 auto;
  padding: 2rem;
  background-color: #f8f9fa;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 600;
  color: #333;
}

.form-group input,
.form-group textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
  transition: border-color 0.3s ease;
}

.form-group input:focus,
.form-group textarea:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 0 2px rgba(0, 123, 255, 0.25);
}

.form-group input.error,
.form-group textarea.error {
  border-color: #dc3545;
}

.error-message {
  display: block;
  margin-top: 0.25rem;
  color: #dc3545;
  font-size: 0.875rem;
}

.submit-button {
  width: 100%;
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 4px;
  background-color: #007bff;
  color: white;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: background-color 0.3s ease;
}

.submit-button:hover:not(:disabled) {
  background-color: #0056b3;
}

.submit-button:disabled {
  background-color: #6c757d;
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .contact-form {
    padding: 1.5rem;
  }
}
EOF
    
    log_event "SUCCESS" "FRONTEND" "React form generated: $name"
}

# Generate layout component
generate_layout() {
    local framework="${1:-react}"
    local layout_name="${2:-MainLayout}"
    local output_dir="${3:-src/layouts}"
    
    mkdir -p "$output_dir"
    
    log_event "INFO" "FRONTEND" "Generating layout: $layout_name"
    
    if [[ "$framework" == "react" ]]; then
        cat > "$output_dir/${layout_name}.jsx" << 'EOF'
import React from 'react';
import PropTypes from 'prop-types';
import './MainLayout.css';

const MainLayout = ({ children }) => {
  return (
    <div className="main-layout">
      <header className="main-header">
        <nav className="navbar">
          <div className="navbar-brand">
            <a href="/">MyApp</a>
          </div>
          <ul className="navbar-menu">
            <li><a href="/">Home</a></li>
            <li><a href="/about">About</a></li>
            <li><a href="/services">Services</a></li>
            <li><a href="/contact">Contact</a></li>
          </ul>
          <div className="navbar-actions">
            <button className="login-button">Login</button>
          </div>
        </nav>
      </header>

      <main className="main-content">
        {children}
      </main>

      <footer className="main-footer">
        <div className="footer-content">
          <div className="footer-section">
            <h3>About</h3>
            <p>Your awesome application built with ZeroDev.</p>
          </div>
          <div className="footer-section">
            <h3>Links</h3>
            <ul>
              <li><a href="/privacy">Privacy Policy</a></li>
              <li><a href="/terms">Terms of Service</a></li>
              <li><a href="/sitemap">Sitemap</a></li>
            </ul>
          </div>
          <div className="footer-section">
            <h3>Connect</h3>
            <ul>
              <li><a href="https://twitter.com">Twitter</a></li>
              <li><a href="https://github.com">GitHub</a></li>
              <li><a href="https://linkedin.com">LinkedIn</a></li>
            </ul>
          </div>
        </div>
        <div className="footer-bottom">
          <p>&copy; 2024 MyApp. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
};

MainLayout.propTypes = {
  children: PropTypes.node.isRequired,
};

export default MainLayout;
EOF

        # Layout CSS
        cat > "$output_dir/${layout_name}.css" << 'EOF'
.main-layout {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

/* Header Styles */
.main-header {
  background-color: #ffffff;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  position: sticky;
  top: 0;
  z-index: 1000;
}

.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.navbar-brand a {
  font-size: 1.5rem;
  font-weight: bold;
  color: #007bff;
  text-decoration: none;
}

.navbar-menu {
  display: flex;
  list-style: none;
  margin: 0;
  padding: 0;
  gap: 2rem;
}

.navbar-menu a {
  color: #333;
  text-decoration: none;
  font-weight: 500;
  transition: color 0.3s ease;
}

.navbar-menu a:hover {
  color: #007bff;
}

.login-button {
  padding: 0.5rem 1rem;
  border: 1px solid #007bff;
  border-radius: 4px;
  background-color: transparent;
  color: #007bff;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.3s ease;
}

.login-button:hover {
  background-color: #007bff;
  color: white;
}

/* Main Content */
.main-content {
  flex: 1;
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
  width: 100%;
}

/* Footer Styles */
.main-footer {
  background-color: #f8f9fa;
  margin-top: auto;
}

.footer-content {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 2rem;
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

.footer-section h3 {
  margin-bottom: 1rem;
  color: #333;
}

.footer-section ul {
  list-style: none;
  padding: 0;
}

.footer-section li {
  margin-bottom: 0.5rem;
}

.footer-section a {
  color: #666;
  text-decoration: none;
  transition: color 0.3s ease;
}

.footer-section a:hover {
  color: #007bff;
}

.footer-bottom {
  background-color: #e9ecef;
  padding: 1rem;
  text-align: center;
  color: #666;
}

/* Responsive Design */
@media (max-width: 768px) {
  .navbar {
    flex-direction: column;
    gap: 1rem;
  }

  .navbar-menu {
    flex-direction: column;
    gap: 1rem;
    text-align: center;
  }

  .footer-content {
    grid-template-columns: 1fr;
  }
}
EOF
    fi
    
    log_event "SUCCESS" "FRONTEND" "Layout generated: $layout_name"
}

# Generate page component
generate_page() {
    local framework="${1:-react}"
    local page_name="${2:-HomePage}"
    local output_dir="${3:-src/pages}"
    
    mkdir -p "$output_dir"
    
    log_event "INFO" "FRONTEND" "Generating page: $page_name"
    
    if [[ "$framework" == "react" ]]; then
        cat > "$output_dir/${page_name}.jsx" << EOF
import React, { useState, useEffect } from 'react';
import MainLayout from '../layouts/MainLayout';
import './${page_name}.css';

const ${page_name} = () => {
  const [data, setData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Simulate data fetching
    const fetchData = async () => {
      try {
        setIsLoading(true);
        // Replace with actual API call
        await new Promise(resolve => setTimeout(resolve, 1000));
        setData([
          { id: 1, title: 'Feature 1', description: 'Amazing feature description' },
          { id: 2, title: 'Feature 2', description: 'Another great feature' },
          { id: 3, title: 'Feature 3', description: 'Best feature ever' },
        ]);
      } catch (error) {
        console.error('Error fetching data:', error);
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, []);

  return (
    <MainLayout>
      <div className="${page_name}">
        <section className="hero-section">
          <h1>Welcome to MyApp</h1>
          <p>Build amazing things with ZeroDev</p>
          <button className="cta-button">Get Started</button>
        </section>

        <section className="features-section">
          <h2>Our Features</h2>
          {isLoading ? (
            <div className="loading">Loading features...</div>
          ) : (
            <div className="features-grid">
              {data.map(feature => (
                <div key={feature.id} className="feature-card">
                  <h3>{feature.title}</h3>
                  <p>{feature.description}</p>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </MainLayout>
  );
};

export default ${page_name};
EOF

        # Page CSS
        cat > "$output_dir/${page_name}.css" << 'EOF'
.HomePage {
  padding: 0;
}

.hero-section {
  text-align: center;
  padding: 4rem 2rem;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border-radius: 8px;
  margin-bottom: 3rem;
}

.hero-section h1 {
  font-size: 3rem;
  margin-bottom: 1rem;
}

.hero-section p {
  font-size: 1.25rem;
  margin-bottom: 2rem;
}

.cta-button {
  padding: 1rem 2rem;
  font-size: 1.125rem;
  border: none;
  border-radius: 50px;
  background-color: white;
  color: #667eea;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.cta-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
}

.features-section {
  margin-bottom: 3rem;
}

.features-section h2 {
  text-align: center;
  margin-bottom: 2rem;
  font-size: 2rem;
  color: #333;
}

.features-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 2rem;
}

.feature-card {
  padding: 2rem;
  background-color: #f8f9fa;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  transition: transform 0.3s ease;
}

.feature-card:hover {
  transform: translateY(-5px);
}

.feature-card h3 {
  margin-bottom: 1rem;
  color: #333;
}

.feature-card p {
  color: #666;
  line-height: 1.6;
}

.loading {
  text-align: center;
  padding: 2rem;
  color: #666;
}

@media (max-width: 768px) {
  .hero-section h1 {
    font-size: 2rem;
  }

  .hero-section p {
    font-size: 1rem;
  }
}
EOF
    fi
    
    log_event "SUCCESS" "FRONTEND" "Page generated: $page_name"
}

# Generate style system
generate_style_system() {
    local output_dir="${1:-src/styles}"
    
    mkdir -p "$output_dir"
    
    log_event "INFO" "FRONTEND" "Generating style system"
    
    # Variables
    cat > "$output_dir/variables.css" << 'EOF'
:root {
  /* Colors */
  --primary-color: #007bff;
  --secondary-color: #6c757d;
  --success-color: #28a745;
  --danger-color: #dc3545;
  --warning-color: #ffc107;
  --info-color: #17a2b8;
  --light-color: #f8f9fa;
  --dark-color: #343a40;
  
  /* Text Colors */
  --text-primary: #333333;
  --text-secondary: #666666;
  --text-muted: #999999;
  
  /* Spacing */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;
  --spacing-xxl: 3rem;
  
  /* Typography */
  --font-family-primary: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  --font-family-mono: 'Courier New', Courier, monospace;
  
  --font-size-xs: 0.75rem;
  --font-size-sm: 0.875rem;
  --font-size-base: 1rem;
  --font-size-lg: 1.125rem;
  --font-size-xl: 1.25rem;
  --font-size-2xl: 1.5rem;
  --font-size-3xl: 2rem;
  
  /* Borders */
  --border-radius-sm: 0.25rem;
  --border-radius-md: 0.5rem;
  --border-radius-lg: 1rem;
  --border-radius-full: 50%;
  
  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.1);
  --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1);
  --shadow-xl: 0 20px 25px rgba(0, 0, 0, 0.1);
  
  /* Z-index */
  --z-index-dropdown: 1000;
  --z-index-sticky: 1020;
  --z-index-fixed: 1030;
  --z-index-modal-backdrop: 1040;
  --z-index-modal: 1050;
  --z-index-popover: 1060;
  --z-index-tooltip: 1070;
  
  /* Transitions */
  --transition-fast: 150ms ease-in-out;
  --transition-base: 300ms ease-in-out;
  --transition-slow: 500ms ease-in-out;
}
EOF

    # Global styles
    cat > "$output_dir/global.css" << 'EOF'
/* Reset and Base Styles */
*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  font-size: 16px;
  -webkit-text-size-adjust: 100%;
  -webkit-tap-highlight-color: transparent;
}

body {
  margin: 0;
  font-family: var(--font-family-primary);
  font-size: var(--font-size-base);
  color: var(--text-primary);
  background-color: white;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* Typography */
h1, h2, h3, h4, h5, h6 {
  margin-top: 0;
  margin-bottom: var(--spacing-md);
  font-weight: 600;
  line-height: 1.2;
}

h1 { font-size: var(--font-size-3xl); }
h2 { font-size: var(--font-size-2xl); }
h3 { font-size: var(--font-size-xl); }
h4 { font-size: var(--font-size-lg); }
h5 { font-size: var(--font-size-base); }
h6 { font-size: var(--font-size-sm); }

p {
  margin-top: 0;
  margin-bottom: var(--spacing-md);
}

/* Links */
a {
  color: var(--primary-color);
  text-decoration: none;
  transition: color var(--transition-fast);
}

a:hover {
  text-decoration: underline;
}

/* Forms */
input,
textarea,
select,
button {
  font-family: inherit;
  font-size: inherit;
  line-height: inherit;
}

/* Images */
img {
  max-width: 100%;
  height: auto;
  vertical-align: middle;
}

/* Tables */
table {
  border-collapse: collapse;
  width: 100%;
}

/* Utility Classes */
.container {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 var(--spacing-md);
}

.text-center { text-align: center; }
.text-left { text-align: left; }
.text-right { text-align: right; }

.mt-0 { margin-top: 0; }
.mt-1 { margin-top: var(--spacing-sm); }
.mt-2 { margin-top: var(--spacing-md); }
.mt-3 { margin-top: var(--spacing-lg); }
.mt-4 { margin-top: var(--spacing-xl); }

.mb-0 { margin-bottom: 0; }
.mb-1 { margin-bottom: var(--spacing-sm); }
.mb-2 { margin-bottom: var(--spacing-md); }
.mb-3 { margin-bottom: var(--spacing-lg); }
.mb-4 { margin-bottom: var(--spacing-xl); }

.hidden { display: none; }
.block { display: block; }
.inline-block { display: inline-block; }
.flex { display: flex; }
.grid { display: grid; }
EOF

    # Button styles
    cat > "$output_dir/buttons.css" << 'EOF'
/* Button Styles */
.btn {
  display: inline-block;
  padding: var(--spacing-sm) var(--spacing-md);
  font-weight: 500;
  text-align: center;
  white-space: nowrap;
  vertical-align: middle;
  user-select: none;
  border: 1px solid transparent;
  border-radius: var(--border-radius-sm);
  transition: all var(--transition-fast);
  cursor: pointer;
}

.btn:hover {
  text-decoration: none;
}

.btn:focus {
  outline: 0;
  box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.25);
}

.btn:disabled {
  opacity: 0.65;
  cursor: not-allowed;
}

/* Button Variants */
.btn-primary {
  color: white;
  background-color: var(--primary-color);
  border-color: var(--primary-color);
}

.btn-primary:hover {
  background-color: #0056b3;
  border-color: #0056b3;
}

.btn-secondary {
  color: white;
  background-color: var(--secondary-color);
  border-color: var(--secondary-color);
}

.btn-success {
  color: white;
  background-color: var(--success-color);
  border-color: var(--success-color);
}

.btn-danger {
  color: white;
  background-color: var(--danger-color);
  border-color: var(--danger-color);
}

.btn-outline-primary {
  color: var(--primary-color);
  background-color: transparent;
  border-color: var(--primary-color);
}

.btn-outline-primary:hover {
  color: white;
  background-color: var(--primary-color);
}

/* Button Sizes */
.btn-sm {
  padding: var(--spacing-xs) var(--spacing-sm);
  font-size: var(--font-size-sm);
}

.btn-lg {
  padding: var(--spacing-md) var(--spacing-lg);
  font-size: var(--font-size-lg);
}

.btn-block {
  display: block;
  width: 100%;
}
EOF
    
    log_event "SUCCESS" "FRONTEND" "Style system generated"
}

# Generate responsive utilities
generate_responsive_utils() {
    local output_file="$FRONTEND_STATE/styles/responsive.css"
    
    cat > "$output_file" << 'EOF'
/* Responsive Breakpoints */
/* Mobile First Approach */

/* Small devices (landscape phones, 576px and up) */
@media (min-width: 576px) {
  .container {
    max-width: 540px;
  }
  
  .col-sm-1 { flex: 0 0 8.333333%; }
  .col-sm-2 { flex: 0 0 16.666667%; }
  .col-sm-3 { flex: 0 0 25%; }
  .col-sm-4 { flex: 0 0 33.333333%; }
  .col-sm-6 { flex: 0 0 50%; }
  .col-sm-12 { flex: 0 0 100%; }
}

/* Medium devices (tablets, 768px and up) */
@media (min-width: 768px) {
  .container {
    max-width: 720px;
  }
  
  .col-md-1 { flex: 0 0 8.333333%; }
  .col-md-2 { flex: 0 0 16.666667%; }
  .col-md-3 { flex: 0 0 25%; }
  .col-md-4 { flex: 0 0 33.333333%; }
  .col-md-6 { flex: 0 0 50%; }
  .col-md-12 { flex: 0 0 100%; }
  
  .hide-md { display: none; }
  .show-md { display: block; }
}

/* Large devices (desktops, 992px and up) */
@media (min-width: 992px) {
  .container {
    max-width: 960px;
  }
  
  .col-lg-1 { flex: 0 0 8.333333%; }
  .col-lg-2 { flex: 0 0 16.666667%; }
  .col-lg-3 { flex: 0 0 25%; }
  .col-lg-4 { flex: 0 0 33.333333%; }
  .col-lg-6 { flex: 0 0 50%; }
  .col-lg-12 { flex: 0 0 100%; }
}

/* Extra large devices (large desktops, 1200px and up) */
@media (min-width: 1200px) {
  .container {
    max-width: 1140px;
  }
  
  .col-xl-1 { flex: 0 0 8.333333%; }
  .col-xl-2 { flex: 0 0 16.666667%; }
  .col-xl-3 { flex: 0 0 25%; }
  .col-xl-4 { flex: 0 0 33.333333%; }
  .col-xl-6 { flex: 0 0 50%; }
  .col-xl-12 { flex: 0 0 100%; }
}

/* Grid System */
.row {
  display: flex;
  flex-wrap: wrap;
  margin-right: -15px;
  margin-left: -15px;
}

.col {
  position: relative;
  width: 100%;
  padding-right: 15px;
  padding-left: 15px;
}
EOF
    
    log_event "SUCCESS" "FRONTEND" "Responsive utilities generated"
}

# Main execution
main() {
    show_banner
    
    case "${1:-help}" in
        component)
            local framework=$(detect_framework)
            generate_react_component "${2:-MyComponent}" "${3:-functional}" "${4:-src/components}"
            ;;
        form)
            local framework=$(detect_framework)
            generate_form_component "$framework" "${2:-ContactForm}" "${3:-src/components/forms}"
            ;;
        layout)
            local framework=$(detect_framework)
            generate_layout "$framework" "${2:-MainLayout}" "${3:-src/layouts}"
            ;;
        page)
            local framework=$(detect_framework)
            generate_page "$framework" "${2:-HomePage}" "${3:-src/pages}"
            ;;
        styles)
            generate_style_system "${2:-src/styles}"
            generate_responsive_utils
            ;;
        init)
            echo -e "${CYAN}Initializing frontend structure...${NC}"
            local framework=$(detect_framework)
            echo -e "${GREEN}Detected framework: $framework${NC}"
            
            # Create directory structure
            mkdir -p src/{components,pages,layouts,styles,utils,hooks,services}
            
            # Generate components
            generate_react_component "Header" "functional" "src/components"
            generate_react_component "Footer" "functional" "src/components"
            generate_form_component "$framework" "ContactForm" "src/components/forms"
            
            # Generate layouts and pages
            generate_layout "$framework" "MainLayout" "src/layouts"
            generate_page "$framework" "HomePage" "src/pages"
            
            # Generate styles
            generate_style_system "src/styles"
            generate_responsive_utils
            
            echo -e "${GREEN}✓ Frontend structure initialized!${NC}"
            ;;
        *)
            echo "Usage: $0 {component|form|layout|page|styles|init} [options]"
            echo ""
            echo "Commands:"
            echo "  component [name] [type] [dir] - Generate component"
            echo "  form [name] [dir]             - Generate form component"
            echo "  layout [name] [dir]           - Generate layout"
            echo "  page [name] [dir]             - Generate page"
            echo "  styles [dir]                  - Generate style system"
            echo "  init                          - Initialize frontend structure"
            exit 1
            ;;
    esac
}

main "$@"