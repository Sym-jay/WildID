"""
SMS Service for ZSI Wildlife Identifier
Handles OTP sending, endangered species alerts, and notifications
Provider: Government of India SMS Gateway (sms.gov.in) or Twilio fallback
"""

import os
import requests
import json
import logging
from datetime import datetime
from typing import Dict, List, Optional
from enum import Enum

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SMSProvider(Enum):
    GOI = "goi"  # Government of India
    TWILIO = "twilio"
    EMAIL = "email"  # Fallback

class SMSService:
    """SMS Service for sending alerts and OTPs"""
    
    def __init__(self, provider: str = "goi", api_key: Optional[str] = None):
        """
        Initialize SMS Service
        
        Args:
            provider: 'goi' (Government), 'twilio', or 'email'
            api_key: API key for the provider
        """
        self.provider = provider.lower()
        self.api_key = api_key or os.getenv('SMS_API_KEY', '')
        self.goi_endpoint = "https://sms.gov.in/api/send"
        self.twilio_endpoint = "https://api.twilio.com/2010-04-01/Accounts"
        self.sms_cost_per_message = 1.50  # INR
        self.sms_log = []
        
    def send_otp(self, phone_number: str, otp_code: str) -> Dict:
        """
        Send OTP verification code via SMS
        
        Args:
            phone_number: User's phone number (format: +91XXXXXXXXXX or 10 digits)
            otp_code: 6-digit OTP code
            
        Returns:
            dict: {'success': bool, 'message': str, 'cost': float}
        """
        try:
            # Validate phone number
            phone = self._validate_phone(phone_number)
            if not phone:
                return {'success': False, 'message': 'Invalid phone number', 'cost': 0}
            
            # Format SMS message
            message = f"Your ZSI Wildlife Identifier verification code is: {otp_code}. Valid for 5 minutes. Do not share."
            
            # Send SMS
            result = self._send_sms(phone, message)
            
            # Log the SMS
            self._log_sms({
                'type': 'OTP',
                'phone': phone,
                'timestamp': datetime.now().isoformat(),
                'status': result.get('success', False),
                'cost': self.sms_cost_per_message
            })
            
            return result
            
        except Exception as e:
            logger.error(f"Error sending OTP: {str(e)}")
            return {'success': False, 'message': f'Error: {str(e)}', 'cost': 0}
    
    def send_endangered_alert(self, expert_phone: str, species_name: str, 
                             user_name: str, location: str) -> Dict:
        """
        Send endangered species alert to experts
        
        Args:
            expert_phone: Expert's phone number
            species_name: Identified species name
            user_name: User who made identification
            location: Where species was spotted
            
        Returns:
            dict: {'success': bool, 'message': str, 'cost': float}
        """
        try:
            phone = self._validate_phone(expert_phone)
            if not phone:
                return {'success': False, 'message': 'Invalid phone number', 'cost': 0}
            
            # Format alert message (keep under 160 chars for single SMS)
            message = f"🐾 {species_name} spotted near {location} by {user_name}. " \
                     f"Open app for details. ZSI Wildlife ID"
            
            if len(message) > 160:
                message = f"🐾 {species_name} at {location}. Check app for details. ZSI"
            
            result = self._send_sms(phone, message)
            
            self._log_sms({
                'type': 'ENDANGERED_ALERT',
                'phone': phone,
                'species': species_name,
                'location': location,
                'user': user_name,
                'timestamp': datetime.now().isoformat(),
                'status': result.get('success', False),
                'cost': self.sms_cost_per_message
            })
            
            return result
            
        except Exception as e:
            logger.error(f"Error sending endangered alert: {str(e)}")
            return {'success': False, 'message': f'Error: {str(e)}', 'cost': 0}
    
    def send_verification_alert(self, user_phone: str, species_name: str, 
                               verified: bool, expert_note: str = "") -> Dict:
        """
        Notify user when their identification is verified
        
        Args:
            user_phone: User's phone number
            species_name: The species they identified
            verified: Whether identification was correct
            expert_note: Expert's comment
            
        Returns:
            dict: {'success': bool, 'message': str, 'cost': float}
        """
        try:
            phone = self._validate_phone(user_phone)
            if not phone:
                return {'success': False, 'message': 'Invalid phone number', 'cost': 0}
            
            status = "✅ CORRECT" if verified else "⚠️ NEEDS REVIEW"
            message = f"Your {species_name} ID was {status}. " \
                     f"Expert: {expert_note[:50] if expert_note else 'Check app for details'}. ZSI"
            
            result = self._send_sms(phone, message)
            
            self._log_sms({
                'type': 'VERIFICATION_ALERT',
                'phone': phone,
                'species': species_name,
                'verified': verified,
                'timestamp': datetime.now().isoformat(),
                'status': result.get('success', False),
                'cost': self.sms_cost_per_message
            })
            
            return result
            
        except Exception as e:
            logger.error(f"Error sending verification alert: {str(e)}")
            return {'success': False, 'message': f'Error: {str(e)}', 'cost': 0}
    
    def _send_sms(self, phone: str, message: str) -> Dict:
        """
        Internal method to send SMS via configured provider
        
        Args:
            phone: Validated phone number
            message: SMS message text
            
        Returns:
            dict: {'success': bool, 'message': str}
        """
        if self.provider == "goi":
            return self._send_via_goi(phone, message)
        elif self.provider == "twilio":
            return self._send_via_twilio(phone, message)
        else:
            return self._send_via_email(phone, message)
    
    def _send_via_goi(self, phone: str, message: str) -> Dict:
        """Send SMS via Government of India gateway"""
        try:
            if not self.api_key:
                logger.warning("No GOI API key configured, using demo mode")
                return {
                    'success': True,
                    'message': f'[DEMO] SMS would be sent to {phone}',
                    'provider': 'goi_demo'
                }
            
            payload = {
                'api_key': self.api_key,
                'phone': phone,
                'message': message,
                'sender_id': 'ZSILIFE'
            }
            
            response = requests.post(self.goi_endpoint, json=payload, timeout=5)
            
            if response.status_code == 200:
                return {'success': True, 'message': 'SMS sent successfully'}
            else:
                return {'success': False, 'message': f'API error: {response.text}'}
                
        except Exception as e:
            logger.error(f"GOI SMS error: {str(e)}")
            return {'success': False, 'message': f'Error: {str(e)}'}
    
    def _send_via_twilio(self, phone: str, message: str) -> Dict:
        """Send SMS via Twilio (fallback)"""
        try:
            twilio_sid = os.getenv('TWILIO_ACCOUNT_SID', '')
            twilio_token = os.getenv('TWILIO_AUTH_TOKEN', '')
            twilio_from = os.getenv('TWILIO_PHONE_NUMBER', '')
            
            if not all([twilio_sid, twilio_token, twilio_from]):
                logger.warning("Twilio not configured, using demo mode")
                return {
                    'success': True,
                    'message': f'[DEMO] SMS would be sent to {phone}',
                    'provider': 'twilio_demo'
                }
            
            url = f"{self.twilio_endpoint}/{twilio_sid}/Messages.json"
            auth = (twilio_sid, twilio_token)
            data = {'From': twilio_from, 'To': phone, 'Body': message}
            
            response = requests.post(url, auth=auth, data=data, timeout=5)
            
            if response.status_code == 201:
                return {'success': True, 'message': 'SMS sent successfully'}
            else:
                return {'success': False, 'message': f'Twilio error: {response.text}'}
                
        except Exception as e:
            logger.error(f"Twilio SMS error: {str(e)}")
            return {'success': False, 'message': f'Error: {str(e)}'}
    
    def _send_via_email(self, phone: str, message: str) -> Dict:
        """Fallback: Send via email (simulated)"""
        logger.info(f"[EMAIL FALLBACK] Would send to {phone}: {message}")
        return {
            'success': True,
            'message': f'[DEMO] Email would be sent (SMS unavailable)',
            'provider': 'email_fallback'
        }
    
    def _validate_phone(self, phone: str) -> Optional[str]:
        """
        Validate and format phone number
        
        Args:
            phone: Phone number in any format
            
        Returns:
            Formatted phone number or None if invalid
        """
        # Remove all non-digits
        digits = ''.join(filter(str.isdigit, phone))
        
        # Check if valid length (10 digits = Indian without country code)
        if len(digits) == 10:
            return f"+91{digits}"
        elif len(digits) == 12 and digits.startswith('91'):
            return f"+{digits}"
        elif len(digits) == 13 and digits.startswith('+91'):
            return digits
        
        logger.warning(f"Invalid phone number: {phone}")
        return None
    
    def _log_sms(self, log_entry: Dict) -> None:
        """Log SMS for audit trail"""
        self.sms_log.append(log_entry)
        logger.info(f"SMS Log: {json.dumps(log_entry)}")
    
    def get_sms_logs(self, limit: int = 100) -> List[Dict]:
        """Get recent SMS logs"""
        return self.sms_log[-limit:]
    
    def get_monthly_cost(self) -> Dict:
        """Calculate monthly SMS costs"""
        total_cost = len(self.sms_log) * self.sms_cost_per_message
        cost_by_type = {}
        
        for log in self.sms_log:
            sms_type = log.get('type', 'UNKNOWN')
            if sms_type not in cost_by_type:
                cost_by_type[sms_type] = 0
            cost_by_type[sms_type] += self.sms_cost_per_message
        
        return {
            'total_sms_sent': len(self.sms_log),
            'total_cost_inr': round(total_cost, 2),
            'cost_per_sms': self.sms_cost_per_message,
            'breakdown_by_type': cost_by_type
        }


# Global SMS service instance
_sms_service = None

def get_sms_service(provider: str = "goi") -> SMSService:
    """Get or create global SMS service instance"""
    global _sms_service
    if _sms_service is None:
        api_key = os.getenv('SMS_API_KEY', '')
        _sms_service = SMSService(provider=provider, api_key=api_key)
    return _sms_service


# Example usage
if __name__ == "__main__":
    # Initialize SMS service
    sms = SMSService(provider="goi")
    
    # Test OTP sending
    print("Testing OTP send...")
    result = sms.send_otp("+919876543210", "123456")
    print(f"OTP Result: {result}")
    
    # Test endangered alert
    print("\nTesting endangered alert...")
    result = sms.send_endangered_alert(
        "+919876543210",
        "Bengal Tiger",
        "User_John",
        "Kaziranga NP"
    )
    print(f"Alert Result: {result}")
    
    # Test verification alert
    print("\nTesting verification alert...")
    result = sms.send_verification_alert(
        "+919876543210",
        "Bengal Tiger",
        True,
        "Excellent photo! Rare sighting."
    )
    print(f"Verification Result: {result}")
    
    # Print costs
    print("\n" + "="*50)
    print("SMS Cost Summary:")
    print(json.dumps(sms.get_monthly_cost(), indent=2))
    print("="*50)
