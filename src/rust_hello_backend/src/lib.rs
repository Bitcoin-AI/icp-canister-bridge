use aes_gcm::{Aes128Gcm, Key, Nonce};
use aes_gcm::aead::{Aead, NewAead};
use ic_cdk::export::candid::{CandidType, Deserialize};
use serde::Serialize;
use base64;

#[derive(CandidType, Deserialize, Debug)]
pub struct EncryptionInput {
    key: String,
    iv: String,
    plaintext: String,
}

#[derive(CandidType, Serialize, Debug)]
pub struct EncryptionOutput {
    ciphertext: String,
}

#[derive(CandidType, Deserialize, Debug)]
pub struct DecryptionInput {
    key: String,
    iv: String,
    ciphertext: String,
}

#[derive(CandidType, Serialize, Debug)]
pub struct DecryptionOutput {
    plaintext: String,
}

#[derive(CandidType, Serialize, Debug)]
pub struct CustomError {
    message: String,
}


#[ic_cdk_macros::query]
fn encrypt(input: EncryptionInput) -> Result<EncryptionOutput, CustomError> {
    if input.key.len() != 16 || input.iv.len() != 12 {
        return Err(CustomError { message: String::from("Key must be 16 bytes and IV must be 12 bytes") });
    }
    

    let key = Key::from_slice(input.key.as_bytes());
    let cipher = Aes128Gcm::new(key);
    let nonce = Nonce::from_slice(input.iv.as_bytes());

    match cipher.encrypt(nonce, input.plaintext.as_bytes()) {
        Ok(ciphertext) => {
            let output = EncryptionOutput { ciphertext: base64::encode(&ciphertext) };
            ic_cdk::println!("Encryption Output: {:?}", output);
            Ok(output)   
        },
        Err(e) => {
            ic_cdk::println!("Encryption failed: {:?}", e);
            Err(CustomError { message: String::from("Encryption failed") })
        },
    }
}

#[ic_cdk_macros::query]
fn decrypt(input: DecryptionInput) -> Result<DecryptionOutput, CustomError> {
    if input.key.len() != 16 || input.iv.len() != 12 {
        return Err(CustomError { message: String::from("Key must be 16 bytes and IV must be 12 bytes") });
    }
    

    let key = Key::from_slice(input.key.as_bytes());
    let cipher = Aes128Gcm::new(key);
    let nonce = Nonce::from_slice(input.iv.as_bytes());

    match cipher.decrypt(nonce, base64::decode(&input.ciphertext).unwrap().as_slice()) {
        Ok(plaintext) => {
            ic_cdk::println!("Decryption Output: {:?}", DecryptionOutput { plaintext: String::from_utf8(plaintext.clone()).unwrap() });
            ic_cdk::println!("Decryption successful");
            Ok(DecryptionOutput { plaintext: String::from_utf8(plaintext).unwrap() })
        },
        Err(_) => Err(CustomError { message: String::from("Decryption failed") }),
    }
}



